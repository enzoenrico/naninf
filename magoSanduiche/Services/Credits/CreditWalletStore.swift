//
//  CreditWalletStore.swift
//  magoSanduiche
//

import Foundation
import Observation
import RevenueCat

/// Observable wallet + storefront. Balance display is a cache of the server ledger only.
@MainActor
@Observable
final class CreditWalletStore {
	private(set) var balance: Int = 0
	private(set) var starterGranted = false
	private(set) var hasActiveStipend = false
	/// When false, Edge Functions are missing/unreachable — generation fail-opens (no local ledger).
	private(set) var ledgerAvailable = false
	private(set) var packages: [StorefrontPackage] = []
	private(set) var isLoadingWallet = false
	private(set) var isLoadingOfferings = false
	private(set) var isPurchasing = false
	private(set) var statusMessage: String?
	private(set) var lastErrorMessage: String?

	private let purchasing: any RevenueCatPurchasing
	private var ledger: (any CreditsLedgerServing)?
	private var accessTokenProvider: (@Sendable () async -> String?)?
	private var identifiedUserID: String?

	init(purchasing: (any RevenueCatPurchasing)? = nil) {
		self.purchasing = purchasing ?? RevenueCatPurchaseService()
		self.purchasing.configureIfNeeded()
	}

	var canPurchase: Bool { purchasing.isConfigured }

	var formattedBalance: String {
		if ledgerAvailable {
			return String(balance)
		}
		return String(localized: "nan_credits_balance_unavailable")
	}

	func bindAccessToken(_ provider: @escaping @Sendable () async -> String?) {
		accessTokenProvider = provider
		if let configuration = CreditsAPIConfiguration.load() {
			ledger = CreditsAPIClient(
				configuration: configuration,
				accessTokenProvider: provider
			)
		} else {
			ledger = nil
		}
	}

	func handleSignedIn(userID: String) async {
		identifiedUserID = userID
		do {
			if purchasing.isConfigured {
				try await purchasing.logIn(appUserID: userID)
			}
		} catch {
			lastErrorMessage = error.localizedDescription
			AppAnalytics.capture("credits_rc_login_failed", properties: [
				"error": error.localizedDescription
			])
		}
		await refreshWallet()
		await refreshOfferings()
	}

	func handleSignedOut() async {
		identifiedUserID = nil
		balance = 0
		starterGranted = false
		hasActiveStipend = false
		ledgerAvailable = false
		packages = []
		do {
			try await purchasing.logOut()
		} catch {
			AppAnalytics.capture("credits_rc_logout_failed", properties: [
				"error": error.localizedDescription
			])
		}
	}

	func refreshWallet() async {
		guard let ledger else {
			ledgerAvailable = false
			return
		}
		isLoadingWallet = true
		defer { isLoadingWallet = false }

		do {
			let snapshot = try await ledger.fetchWallet()
			apply(snapshot)
			await refreshCustomerEntitlements()
			AppAnalytics.capture("credits_wallet_refreshed", properties: [
				"balance": snapshot.balance,
				"starter_granted": snapshot.starterGranted,
				"has_stipend": hasActiveStipend
			])
		} catch let error as CreditsLedgerError {
			handleLedgerError(error)
		} catch {
			ledgerAvailable = false
			lastErrorMessage = error.localizedDescription
		}
	}

	func refreshOfferings() async {
		guard purchasing.isConfigured else {
			packages = []
			return
		}
		isLoadingOfferings = true
		defer { isLoadingOfferings = false }
		do {
			packages = try await purchasing.refreshOfferings()
			await refreshCustomerEntitlements()
		} catch {
			lastErrorMessage = error.localizedDescription
			AppAnalytics.capture("credits_offerings_failed", properties: [
				"error": error.localizedDescription
			])
		}
	}

	private func refreshCustomerEntitlements() async {
		guard purchasing.isConfigured else { return }
		do {
			let info = try await purchasing.customerInfo()
			hasActiveStipend = info.entitlements[CreditCatalog.Entitlement.scribe]?.isActive == true
		} catch {
			// Ledger snapshot may still populate hasActiveStipend; ignore RC entitlement errors.
		}
	}

	@discardableResult
	func purchase(_ storePackage: StorefrontPackage) async -> Bool {
		guard purchasing.isConfigured else {
			lastErrorMessage = RevenueCatConfigurationError.missingAPIKey.localizedDescription
			return false
		}
		isPurchasing = true
		statusMessage = nil
		lastErrorMessage = nil
		defer { isPurchasing = false }

		do {
			_ = try await purchasing.purchase(storePackage.package)
			AppAnalytics.capture("credits_purchase_succeeded", properties: [
				"product_id": storePackage.kind.productID,
				"package_id": storePackage.id
			])
			statusMessage = String(localized: "nan_credits_purchase_success")
			await refreshCustomerEntitlements()
			await refreshWallet()
			return true
		} catch {
			if error is CancellationError || isUserCancelled(error) {
				return false
			}
			lastErrorMessage = error.localizedDescription
			AppAnalytics.capture("credits_purchase_failed", properties: [
				"product_id": storePackage.kind.productID,
				"error": error.localizedDescription
			])
			return false
		}
	}

	@discardableResult
	func restorePurchases() async -> Bool {
		guard purchasing.isConfigured else {
			lastErrorMessage = RevenueCatConfigurationError.missingAPIKey.localizedDescription
			return false
		}
		isPurchasing = true
		defer { isPurchasing = false }
		do {
			_ = try await purchasing.restorePurchases()
			statusMessage = String(localized: "nan_credits_restore_success")
			await refreshCustomerEntitlements()
			await refreshWallet()
			AppAnalytics.capture("credits_restore_succeeded")
			return true
		} catch {
			lastErrorMessage = error.localizedDescription
			AppAnalytics.capture("credits_restore_failed", properties: [
				"error": error.localizedDescription
			])
			return false
		}
	}

	/// Preflight for a DM turn. Returns nil when play may proceed.
	func preflightDMTurn(generationID: String) async -> CreditsLedgerError? {
		let required = CreditCatalog.cost(for: .dmTurn)
		guard ledgerAvailable, let ledger else {
			AppAnalytics.capture("credits_metering_fail_open", properties: [
				"reason": "ledger_unavailable",
				"spend": CreditSpendKind.dmTurn.rawValue
			])
			return nil
		}
		if balance < required {
			return .insufficientCredits(balance: balance, required: required)
		}
		do {
			let hold = try await ledger.hold(
				spend: .dmTurn,
				generationID: generationID,
				idempotencyKey: "hold:dm:\(generationID)"
			)
			PendingCreditHolds.shared.store(holdID: hold.holdID, generationID: generationID, spend: .dmTurn)
			balance = hold.balance
			return nil
		} catch let error as CreditsLedgerError {
			handleLedgerError(error)
			switch error {
			case .unavailable, .notConfigured:
				return nil
			case .insufficientCredits, .unauthorized, .server:
				return error
			}
		} catch {
			AppAnalytics.capture("credits_metering_fail_open", properties: [
				"reason": "hold_threw",
				"error": error.localizedDescription
			])
			return nil
		}
	}

	func finalizeDMTurn(generationID: String, succeeded: Bool) async {
		guard let holdID = PendingCreditHolds.shared.take(generationID: generationID) else { return }
		guard let ledger, ledgerAvailable else { return }
		do {
			let snapshot: CreditWalletSnapshot
			if succeeded {
				snapshot = try await ledger.capture(holdID: holdID, generationID: generationID)
			} else {
				snapshot = try await ledger.release(holdID: holdID, generationID: generationID)
			}
			apply(snapshot)
		} catch {
			AppAnalytics.capture("credits_finalize_failed", properties: [
				"generation_id": generationID,
				"succeeded": succeeded,
				"error": error.localizedDescription
			])
			await refreshWallet()
		}
	}

	/// Charge scene image only after provider success (no local deduction as truth).
	func chargeSceneImageIfNeeded(generationID: String) async {
		guard ledgerAvailable, let ledger else { return }
		do {
			let snapshot = try await ledger.charge(
				spend: .sceneImage,
				generationID: generationID,
				idempotencyKey: "charge:image:\(generationID)"
			)
			apply(snapshot)
		} catch let error as CreditsLedgerError {
			handleLedgerError(error)
			AppAnalytics.capture("credits_image_charge_failed", properties: [
				"error": error.localizedDescription
			])
		} catch {
			AppAnalytics.capture("credits_image_charge_failed", properties: [
				"error": error.localizedDescription
			])
		}
	}

	func canAffordSceneImage() -> Bool {
		guard ledgerAvailable else { return true }
		return balance >= CreditCatalog.cost(for: .sceneImage)
	}

	private func apply(_ snapshot: CreditWalletSnapshot) {
		balance = snapshot.balance
		starterGranted = snapshot.starterGranted
		// Prefer live RC `scribe` entitlement when available; ledger hint is fallback only.
		if !purchasing.isConfigured {
			hasActiveStipend = snapshot.hasActiveStipend
		}
		ledgerAvailable = snapshot.ledgerAvailable
		lastErrorMessage = nil
	}

	private func handleLedgerError(_ error: CreditsLedgerError) {
		switch error {
		case .unavailable, .notConfigured:
			ledgerAvailable = false
			lastErrorMessage = nil
		case .unauthorized, .insufficientCredits, .server:
			lastErrorMessage = error.localizedDescription
		}
	}

	private func isUserCancelled(_ error: Error) -> Bool {
		if let code = error as? ErrorCode {
			return code == .purchaseCancelledError
		}
		return (error as NSError).code == ErrorCode.purchaseCancelledError.rawValue
	}
}

/// In-flight hold IDs keyed by generation / turn id. Not a ledger — only bridges hold→finalize.
final class PendingCreditHolds: @unchecked Sendable {
	static let shared = PendingCreditHolds()
	private let lock = NSLock()
	private var holds: [String: String] = [:]

	func store(holdID: String, generationID: String, spend: CreditSpendKind) {
		_ = spend
		lock.lock()
		holds[generationID] = holdID
		lock.unlock()
	}

	func take(generationID: String) -> String? {
		lock.lock()
		defer { lock.unlock() }
		return holds.removeValue(forKey: generationID)
	}
}

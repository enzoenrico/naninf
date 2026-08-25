//
//  RevenueCatPurchasing.swift
//  magoSanduiche
//

import Foundation
import RevenueCat

enum RevenueCatConfigurationError: Error, LocalizedError {
	case missingAPIKey

	var errorDescription: String? {
		switch self {
		case .missingAPIKey:
			String(localized: "nan_credits_error_rc_missing_key")
		}
	}
}

enum NanInfPackageKind: String, CaseIterable, Identifiable {
	case starter40
	case plus100
	case vault250
	case stipendMonthly

	var id: String { rawValue }

	var productID: String {
		switch self {
		case .starter40:
			CreditCatalog.ProductID.starter40
		case .plus100:
			CreditCatalog.ProductID.plus100
		case .vault250:
			CreditCatalog.ProductID.vault250
		case .stipendMonthly:
			CreditCatalog.ProductID.stipendMonthly
		}
	}

	var titleKey: String {
		switch self {
		case .starter40:
			"nan_credits_pack_starter_title"
		case .plus100:
			"nan_credits_pack_plus_title"
		case .vault250:
			"nan_credits_pack_vault_title"
		case .stipendMonthly:
			"nan_credits_pack_stipend_title"
		}
	}

	var detailKey: String {
		switch self {
		case .starter40:
			"nan_credits_pack_starter_detail"
		case .plus100:
			"nan_credits_pack_plus_detail"
		case .vault250:
			"nan_credits_pack_vault_detail"
		case .stipendMonthly:
			"nan_credits_pack_stipend_detail"
		}
	}

	static func kind(forProductID productID: String) -> NanInfPackageKind? {
		allCases.first { $0.productID == productID }
	}
}

struct StorefrontPackage: Identifiable, Equatable {
	let id: String
	let kind: NanInfPackageKind
	let package: Package
	let localizedPrice: String

	static func == (lhs: StorefrontPackage, rhs: StorefrontPackage) -> Bool {
		lhs.id == rhs.id && lhs.localizedPrice == rhs.localizedPrice
	}
}

@MainActor
protocol RevenueCatPurchasing: AnyObject {
	var isConfigured: Bool { get }
	func configureIfNeeded()
	func logIn(appUserID: String) async throws
	func logOut() async throws
	func refreshOfferings() async throws -> [StorefrontPackage]
	func purchase(_ package: Package) async throws -> CustomerInfo
	func restorePurchases() async throws -> CustomerInfo
	func customerInfo() async throws -> CustomerInfo
}

@MainActor
final class RevenueCatPurchaseService: RevenueCatPurchasing {
	private(set) var isConfigured = false
	private let apiKey: String?

	init(bundle: Bundle = .main) {
		let raw = bundle.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String
		let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		if trimmed.isEmpty || trimmed.contains("$(") || trimmed == "REPLACE_ME" {
			apiKey = nil
		} else {
			apiKey = trimmed
		}
	}

	func configureIfNeeded() {
		guard !isConfigured else { return }
		guard let apiKey else { return }
		Purchases.logLevel = .warn
		Purchases.configure(withAPIKey: apiKey)
		isConfigured = true
	}

	func logIn(appUserID: String) async throws {
		configureIfNeeded()
		guard isConfigured else { throw RevenueCatConfigurationError.missingAPIKey }
		_ = try await Purchases.shared.logIn(appUserID)
	}

	func logOut() async throws {
		guard isConfigured else { return }
		_ = try await Purchases.shared.logOut()
	}

	func refreshOfferings() async throws -> [StorefrontPackage] {
		configureIfNeeded()
		guard isConfigured else { throw RevenueCatConfigurationError.missingAPIKey }
		let offerings = try await Purchases.shared.offerings()
		let offering = offerings.current ?? offerings.offering(identifier: CreditCatalog.OfferingID.default)
		guard let offering else { return [] }

		return offering.availablePackages.compactMap { package in
			guard let kind = NanInfPackageKind.kind(forProductID: package.storeProduct.productIdentifier) else {
				return nil
			}
			return StorefrontPackage(
				id: package.identifier,
				kind: kind,
				package: package,
				localizedPrice: package.storeProduct.localizedPriceString
			)
		}
		.sorted { lhs, rhs in
			packageSortIndex(lhs.kind) < packageSortIndex(rhs.kind)
		}
	}

	func purchase(_ package: Package) async throws -> CustomerInfo {
		configureIfNeeded()
		guard isConfigured else { throw RevenueCatConfigurationError.missingAPIKey }
		let result = try await Purchases.shared.purchase(package: package)
		return result.customerInfo
	}

	func restorePurchases() async throws -> CustomerInfo {
		configureIfNeeded()
		guard isConfigured else { throw RevenueCatConfigurationError.missingAPIKey }
		return try await Purchases.shared.restorePurchases()
	}

	func customerInfo() async throws -> CustomerInfo {
		configureIfNeeded()
		guard isConfigured else { throw RevenueCatConfigurationError.missingAPIKey }
		return try await Purchases.shared.customerInfo()
	}

	private func packageSortIndex(_ kind: NanInfPackageKind) -> Int {
		switch kind {
		case .starter40: 0
		case .plus100: 1
		case .vault250: 2
		case .stipendMonthly: 3
		}
	}
}

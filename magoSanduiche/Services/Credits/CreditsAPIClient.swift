//
//  CreditsAPIClient.swift
//  magoSanduiche
//

import Foundation

/// Contract for the Supabase Edge Function credit ledger.
/// Source of truth is server-side; this client never persists a spend ledger locally.
protocol CreditsLedgerServing: AnyObject, Sendable {
	func fetchWallet() async throws -> CreditWalletSnapshot
	func hold(spend: CreditSpendKind, generationID: String, idempotencyKey: String) async throws -> CreditHoldReceipt
	func capture(holdID: String, generationID: String) async throws -> CreditWalletSnapshot
	func release(holdID: String, generationID: String) async throws -> CreditWalletSnapshot
	func charge(spend: CreditSpendKind, generationID: String, idempotencyKey: String) async throws -> CreditWalletSnapshot
}

struct CreditWalletSnapshot: Codable, Sendable, Equatable {
	var balance: Int
	var starterGranted: Bool
	var hasActiveStipend: Bool
	var ledgerAvailable: Bool

	static let unavailable = CreditWalletSnapshot(
		balance: 0,
		starterGranted: false,
		hasActiveStipend: false,
		ledgerAvailable: false
	)
}

struct CreditHoldReceipt: Codable, Sendable, Equatable {
	var holdID: String
	var balance: Int
	var cost: Int
}

enum CreditsLedgerError: Error, LocalizedError, Equatable {
	case notConfigured
	case unauthorized
	case insufficientCredits(balance: Int, required: Int)
	case unavailable(String)
	case server(String)

	var errorDescription: String? {
		switch self {
		case .notConfigured:
			String(localized: "nan_credits_error_not_configured")
		case .unauthorized:
			String(localized: "nan_credits_error_unauthorized")
		case let .insufficientCredits(balance, required):
			String(
				format: String(localized: "nan_credits_error_insufficient_format"),
				required,
				balance
			)
		case let .unavailable(message):
			message
		case let .server(message):
			message
		}
	}
}

struct CreditsAPIConfiguration: Sendable {
	let supabaseURL: URL
	let publishableKey: String

	var walletURL: URL { supabaseURL.appending(path: "functions/v1/credits-wallet") }
	var meterURL: URL { supabaseURL.appending(path: "functions/v1/credits-meter") }

	static func load(bundle: Bundle = .main) -> CreditsAPIConfiguration? {
		guard
			let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
			let url = URL(string: urlString),
			!urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
			let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
			!key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
			!key.contains("$(")
		else {
			return nil
		}
		return CreditsAPIConfiguration(supabaseURL: url, publishableKey: key)
	}
}

/// HTTP client for `credits-wallet` and `credits-meter` Edge Functions.
final class CreditsAPIClient: CreditsLedgerServing, @unchecked Sendable {
	private let configuration: CreditsAPIConfiguration
	private let session: URLSession
	private let accessTokenProvider: @Sendable () async -> String?

	init(
		configuration: CreditsAPIConfiguration,
		accessTokenProvider: @escaping @Sendable () async -> String?,
		session: URLSession = .shared
	) {
		self.configuration = configuration
		self.accessTokenProvider = accessTokenProvider
		self.session = session
	}

	func fetchWallet() async throws -> CreditWalletSnapshot {
		var request = try await authorizedRequest(url: configuration.walletURL, method: "POST")
		request.httpBody = try JSONEncoder().encode(WalletRequest(action: "ensure"))
		return try await decode(CreditWalletSnapshot.self, from: request)
	}

	func hold(
		spend: CreditSpendKind,
		generationID: String,
		idempotencyKey: String
	) async throws -> CreditHoldReceipt {
		var request = try await authorizedRequest(url: configuration.meterURL, method: "POST")
		request.httpBody = try JSONEncoder().encode(
			MeterRequest(
				action: "hold",
				spend: spend.rawValue,
				generationID: generationID,
				idempotencyKey: idempotencyKey,
				holdID: nil
			)
		)
		return try await decode(CreditHoldReceipt.self, from: request)
	}

	func capture(holdID: String, generationID: String) async throws -> CreditWalletSnapshot {
		var request = try await authorizedRequest(url: configuration.meterURL, method: "POST")
		request.httpBody = try JSONEncoder().encode(
			MeterRequest(
				action: "capture",
				spend: nil,
				generationID: generationID,
				idempotencyKey: "capture:\(holdID)",
				holdID: holdID
			)
		)
		return try await decode(CreditWalletSnapshot.self, from: request)
	}

	func release(holdID: String, generationID: String) async throws -> CreditWalletSnapshot {
		var request = try await authorizedRequest(url: configuration.meterURL, method: "POST")
		request.httpBody = try JSONEncoder().encode(
			MeterRequest(
				action: "release",
				spend: nil,
				generationID: generationID,
				idempotencyKey: "release:\(holdID)",
				holdID: holdID
			)
		)
		return try await decode(CreditWalletSnapshot.self, from: request)
	}

	func charge(
		spend: CreditSpendKind,
		generationID: String,
		idempotencyKey: String
	) async throws -> CreditWalletSnapshot {
		var request = try await authorizedRequest(url: configuration.meterURL, method: "POST")
		request.httpBody = try JSONEncoder().encode(
			MeterRequest(
				action: "charge",
				spend: spend.rawValue,
				generationID: generationID,
				idempotencyKey: idempotencyKey,
				holdID: nil
			)
		)
		return try await decode(CreditWalletSnapshot.self, from: request)
	}

	private func authorizedRequest(url: URL, method: String) async throws -> URLRequest {
		guard let token = await accessTokenProvider(), !token.isEmpty else {
			throw CreditsLedgerError.unauthorized
		}
		var request = URLRequest(url: url)
		request.httpMethod = method
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		return request
	}

	private func decode<T: Decodable>(_ type: T.Type, from request: URLRequest) async throws -> T {
		let (data, response): (Data, URLResponse)
		do {
			(data, response) = try await session.data(for: request)
		} catch {
			throw CreditsLedgerError.unavailable(error.localizedDescription)
		}

		guard let http = response as? HTTPURLResponse else {
			throw CreditsLedgerError.unavailable("Invalid credits response.")
		}

		switch http.statusCode {
		case 200 ... 299:
			do {
				return try JSONDecoder().decode(T.self, from: data)
			} catch {
				throw CreditsLedgerError.server("Could not decode credits response.")
			}
		case 401, 403:
			throw CreditsLedgerError.unauthorized
		case 402:
			let payload = try? JSONDecoder().decode(InsufficientPayload.self, from: data)
			throw CreditsLedgerError.insufficientCredits(
				balance: payload?.balance ?? 0,
				required: payload?.required ?? 0
			)
		case 404, 502, 503, 504:
			throw CreditsLedgerError.unavailable("Credits ledger is not deployed yet.")
		default:
			let message = (try? JSONDecoder().decode(ErrorPayload.self, from: data))?.error
				?? "Credits request failed (\(http.statusCode))."
			throw CreditsLedgerError.server(message)
		}
	}
}

private struct WalletRequest: Encodable {
	let action: String
}

private struct MeterRequest: Encodable {
	let action: String
	let spend: String?
	let generationID: String
	let idempotencyKey: String
	let holdID: String?

	enum CodingKeys: String, CodingKey {
		case action
		case spend
		case generationID = "generation_id"
		case idempotencyKey = "idempotency_key"
		case holdID = "hold_id"
	}
}

private struct InsufficientPayload: Decodable {
	let balance: Int
	let required: Int
}

private struct ErrorPayload: Decodable {
	let error: String
}

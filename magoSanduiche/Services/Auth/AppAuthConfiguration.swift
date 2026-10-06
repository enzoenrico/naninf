//
//  AppAuthConfiguration.swift
//  magoSanduiche
//

import Foundation

struct AppAuthConfiguration {
	let supabaseURL: URL
	let supabasePublishableKey: String

	static func load(bundle: Bundle = .main) throws -> AppAuthConfiguration {
		try load(infoDictionary: bundle.infoDictionary ?? [:])
	}

	static func load(infoDictionary: [String: Any]) throws -> AppAuthConfiguration {
		guard let supabaseURLString = sanitizedString(for: "SUPABASE_URL", in: infoDictionary),
			let supabaseURL = URL(string: supabaseURLString)
		else {
			throw AppAuthConfigurationError.missingValue("SUPABASE_URL")
		}

		guard let supabasePublishableKey = sanitizedString(for: "SUPABASE_PUBLISHABLE_KEY", in: infoDictionary) else {
			throw AppAuthConfigurationError.missingValue("SUPABASE_PUBLISHABLE_KEY")
		}

		return AppAuthConfiguration(
			supabaseURL: supabaseURL,
			supabasePublishableKey: supabasePublishableKey
		)
	}

	private static func sanitizedString(for key: String, in infoDictionary: [String: Any]) -> String? {
		guard let value = infoDictionary[key] as? String else { return nil }
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		guard !trimmed.hasPrefix("$(") else { return nil }
		return trimmed
	}
}

enum AppAuthConfigurationError: LocalizedError {
	case missingValue(String)

	var errorDescription: String? {
		switch self {
		case .missingValue(let key):
			"Missing auth configuration value: \(key)."
		}
	}
}

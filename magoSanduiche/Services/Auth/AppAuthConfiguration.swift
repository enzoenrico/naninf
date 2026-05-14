//
//  AppAuthConfiguration.swift
//  magoSanduiche
//

import Foundation

struct AppAuthConfiguration {
	let supabaseURL: URL
	let supabasePublishableKey: String
	/// OAuth **Web application** client ID from Google Cloud. Use this as `GIDConfiguration.serverClientID` when present so the ID token audience matches Supabase's Google provider.
	let googleServerClientID: String?
	let googleIOSClientID: String

	static func load(bundle: Bundle = .main) throws -> AppAuthConfiguration {
		guard let supabaseURLString = sanitizedString(for: "SUPABASE_URL", in: bundle),
			let supabaseURL = URL(string: supabaseURLString)
		else {
			throw AppAuthConfigurationError.missingValue("SUPABASE_URL")
		}

		guard let supabasePublishableKey = sanitizedString(for: "SUPABASE_PUBLISHABLE_KEY", in: bundle) else {
			throw AppAuthConfigurationError.missingValue("SUPABASE_PUBLISHABLE_KEY")
		}

		let google = try googleSignInIdentifiers(bundle: bundle)

		return AppAuthConfiguration(
			supabaseURL: supabaseURL,
			supabasePublishableKey: supabasePublishableKey,
			googleServerClientID: google.server,
			googleIOSClientID: google.ios
		)
	}

	private struct GoogleIdentifiers {
		var ios: String
		var server: String?
	}

	private static func googleSignInIdentifiers(bundle: Bundle) throws -> GoogleIdentifiers {
		let serverFromPlist =
			pluckGoogleOAuthValue(key: "SERVER_CLIENT_ID", fromPlistNamed: "GoogleOAuthClient", in: bundle)?
				.nilIfBlank
				?? pluckGoogleOAuthValue(key: "WEB_CLIENT_ID", fromPlistNamed: "GoogleOAuthClient", in: bundle)?
				.nilIfBlank

		if let ios = sanitizedString(for: "GOOGLE_IOS_CLIENT_ID", in: bundle) {
			let server =
				sanitizedString(for: "GOOGLE_WEB_CLIENT_ID", in: bundle)?.nilIfBlank ?? serverFromPlist
			return GoogleIdentifiers(ios: ios, server: server)
		}

		guard let ios = pluckGoogleOAuthValue(key: "CLIENT_ID", fromPlistNamed: "GoogleOAuthClient", in: bundle)?
			.nilIfBlank
		else {
			throw AppAuthConfigurationError.missingValue("Google OAuth iOS CLIENT_ID (GoogleOAuthClient.plist or GOOGLE_IOS_CLIENT_ID)")
		}

		let server = serverFromPlist
		return GoogleIdentifiers(ios: ios, server: server)
	}

	private static func pluckGoogleOAuthValue(key: String, fromPlistNamed name: String, in bundle: Bundle)
		-> String?
	{
		guard let url = bundle.url(forResource: name, withExtension: "plist"),
			let dict = NSDictionary(contentsOf: url) as? [String: Any],
			let value = dict[key] as? String
		else {
			return nil
		}
		return value
	}

	private static func sanitizedString(for key: String, in bundle: Bundle) -> String? {
		guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
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

private extension String {
	var nilIfBlank: String? {
		let t = trimmingCharacters(in: .whitespacesAndNewlines)
		return t.isEmpty ? nil : t
	}
}

//
//  SupabaseAuthService.swift
//  magoSanduiche
//

import AuthenticationServices
import Foundation
import Supabase

final class SupabaseAuthService {
	private let client: SupabaseClient

	init(configuration: AppAuthConfiguration) {
		client = SupabaseClient(
			supabaseURL: configuration.supabaseURL,
			supabaseKey: configuration.supabasePublishableKey
		)
	}

	var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> {
		client.auth.authStateChanges
	}

	func currentSession() async throws -> Session {
		try await client.auth.session
	}

	func signInWithApple(_ result: Result<ASAuthorization, Error>) async throws -> Session {
		let authorization = try result.get()
		guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
			throw AuthServiceError.missingAppleCredential
		}
		guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
			throw AuthServiceError.missingIdentityToken
		}

		let session = try await client.auth.signInWithIdToken(
			credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken)
		)

		if let metadata = appleNameMetadata(from: credential.fullName) {
			try await client.auth.update(user: UserAttributes(data: metadata))
		}

		return session
	}

	func signOut() async throws {
		try await client.auth.signOut()
	}

	private func appleNameMetadata(from name: PersonNameComponents?) -> [String: AnyJSON]? {
		guard let name else { return nil }

		var parts: [String] = []
		if let givenName = name.givenName, !givenName.isEmpty {
			parts.append(givenName)
		}
		if let middleName = name.middleName, !middleName.isEmpty {
			parts.append(middleName)
		}
		if let familyName = name.familyName, !familyName.isEmpty {
			parts.append(familyName)
		}

		guard !parts.isEmpty else { return nil }
		return [
			"full_name": .string(parts.joined(separator: " ")),
			"given_name": .string(name.givenName ?? ""),
			"family_name": .string(name.familyName ?? "")
		]
	}
}

enum AuthServiceError: LocalizedError {
	case missingAppleCredential
	case missingIdentityToken

	var errorDescription: String? {
		switch self {
		case .missingAppleCredential:
			"Apple did not return a valid authorization credential."
		case .missingIdentityToken:
			"The identity provider did not return an ID token."
		}
	}
}

//
//  SupabaseAuthService.swift
//  magoSanduiche
//

import AuthenticationServices
import Foundation
import GoogleSignIn
import Supabase

#if canImport(UIKit)
	import UIKit
#endif

final class SupabaseAuthService {
	private let client: SupabaseClient

	init(configuration: AppAuthConfiguration) {
		client = SupabaseClient(
			supabaseURL: configuration.supabaseURL,
			supabaseKey: configuration.supabasePublishableKey
		)

		if let serverClientID = configuration.googleServerClientID {
			GIDSignIn.sharedInstance.configuration = GIDConfiguration(
				clientID: configuration.googleIOSClientID,
				serverClientID: serverClientID
			)
		} else {
			GIDSignIn.sharedInstance.configuration = GIDConfiguration(
				clientID: configuration.googleIOSClientID
			)
		}
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

	@MainActor
	func signInWithGoogle() async throws -> Session {
		#if canImport(UIKit)
			guard let presentingViewController = UIApplication.shared.authPresentingViewController else {
				throw AuthServiceError.missingPresentingViewController
			}

			let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
			guard let idToken = result.user.idToken?.tokenString else {
				throw AuthServiceError.missingIdentityToken
			}

			let accessToken = result.user.accessToken.tokenString
			return try await client.auth.signInWithIdToken(
				credentials: OpenIDConnectCredentials(
					provider: .google,
					idToken: idToken,
					accessToken: accessToken
				)
			)
		#else
			throw AuthServiceError.unsupportedPlatform
		#endif
	}

	func signOut() async throws {
		try await client.auth.signOut()
		GIDSignIn.sharedInstance.signOut()
	}

	@discardableResult
	func handleOpenURL(_ url: URL) -> Bool {
		GIDSignIn.sharedInstance.handle(url)
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
	case missingPresentingViewController
	case unsupportedPlatform

	var errorDescription: String? {
		switch self {
		case .missingAppleCredential:
			"Apple did not return a valid authorization credential."
		case .missingIdentityToken:
			"The identity provider did not return an ID token."
		case .missingPresentingViewController:
			"Could not find a screen for the Google sign-in prompt."
		case .unsupportedPlatform:
			"Native Google sign-in is only available on UIKit platforms."
		}
	}
}

#if canImport(UIKit)
	private extension UIApplication {
		var authPresentingViewController: UIViewController? {
			connectedScenes
				.compactMap { $0 as? UIWindowScene }
				.flatMap(\.windows)
				.first { $0.isKeyWindow }?
				.rootViewController?
				.topPresentedViewController
		}
	}

	private extension UIViewController {
		var topPresentedViewController: UIViewController {
			if let presentedViewController {
				return presentedViewController.topPresentedViewController
			}
			if let navigationController = self as? UINavigationController,
				let visibleViewController = navigationController.visibleViewController
			{
				return visibleViewController.topPresentedViewController
			}
			if let tabBarController = self as? UITabBarController,
				let selectedViewController = tabBarController.selectedViewController
			{
				return selectedViewController.topPresentedViewController
			}
			return self
		}
	}
#endif

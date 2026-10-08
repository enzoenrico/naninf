//
//  AuthSessionStore.swift
//  magoSanduiche
//

import AuthenticationServices
import Foundation

@MainActor
@Observable
final class AuthSessionStore {
	private let snapshotStore: AuthLoginSnapshotStore
	private var hasStarted = false
	private var isUITestMode = false

	private(set) var loginSnapshot: AuthLoginSnapshot?
	private(set) var isAuthenticated = false
	private(set) var isLoadingSession = true
	private(set) var isAuthenticating = false
	private(set) var errorMessage: String?
	private(set) var configurationMessage: String?

	init(defaults: UserDefaults = .standard) {
		snapshotStore = AuthLoginSnapshotStore(defaults: defaults)
		loginSnapshot = snapshotStore.load()
	}

	#if DEBUG
		/// Builds a store with a fixed, network-free state for UI-test screenshots.
		init(uiTestMode mode: UITestAuthMode, defaults: UserDefaults = .standard) {
			snapshotStore = AuthLoginSnapshotStore(defaults: defaults)
			isUITestMode = true
			isLoadingSession = false

			switch mode {
			case .authenticated:
				loginSnapshot = AuthLoginSnapshot(
					userID: "00000000-0000-0000-0000-000000000001",
					email: "wizard@mago.test",
					provider: .apple,
					displayName: "Sandwich Wizard",
					signedInAt: Date(timeIntervalSince1970: 1_700_000_000)
				)
				isAuthenticated = true
			case .unauthenticated:
				isAuthenticated = false
			case .configMissing:
				isAuthenticated = false
				configurationMessage = String(localized: "nan_auth_config_missing")
			case .error:
				isAuthenticated = false
				errorMessage = "Bind failed: the gate rejected your sigil. Try again."
			case .loading:
				isAuthenticated = false
				isLoadingSession = true
			}
		}
	#endif

	func start() async {
		guard !hasStarted else { return }
		hasStarted = true

		if isUITestMode { return }

		await restoreStoredSession()
	}

	func handleAppleSignInButtonCompletion(_ result: Result<ASAuthorization, Error>) async {
		isAuthenticating = true
		errorMessage = nil
		defer { isAuthenticating = false }

		do {
			let snapshot = try snapshot(from: result)
			store(snapshot)
			AppAnalytics.capture("auth_signed_in", properties: [
				"provider": PlayerAuthProvider.apple.rawValue
			])
		} catch let error as ASAuthorizationError where error.code == .canceled {
			return
		} catch {
			errorMessage = error.localizedDescription
			let nsError = error as NSError
			AppAnalytics.capture("auth_sign_in_failed", properties: [
				"provider": PlayerAuthProvider.apple.rawValue,
				"error_domain": nsError.domain,
				"error_code": nsError.code,
				"error": AppAnalytics.clipped(nsError.localizedDescription),
			])
		}
	}

	func signOut() async {
		isAuthenticating = true
		errorMessage = nil
		defer { isAuthenticating = false }

		clearSession()
		AppAnalytics.capture("auth_signed_out")
		AppAnalytics.markSignedOut()
	}

	private func restoreStoredSession() async {
		isLoadingSession = true
		defer { isLoadingSession = false }

		guard let snapshot = loginSnapshot else {
			isAuthenticated = false
			return
		}

		if snapshot.provider == .apple, await appleCredentialRevoked(userID: snapshot.userID) {
			clearSession()
			return
		}

		isAuthenticated = true
		AppAnalytics.identifySignedInPlayer(userID: snapshot.userID, provider: snapshot.provider.rawValue)
	}

	private func snapshot(from result: Result<ASAuthorization, Error>) throws -> AuthLoginSnapshot {
		let authorization = try result.get()
		guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
			throw AuthServiceError.missingAppleCredential
		}

		let userID = credential.user.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !userID.isEmpty else {
			throw AuthServiceError.missingAppleUserID
		}

		let previous = previousSnapshot(for: userID)
		return AuthLoginSnapshot(
			userID: userID,
			email: credential.email ?? previous?.email,
			provider: .apple,
			displayName: Self.displayName(from: credential.fullName) ?? previous?.displayName
		)
	}

	private func previousSnapshot(for userID: String) -> AuthLoginSnapshot? {
		if loginSnapshot?.userID == userID {
			return loginSnapshot
		}
		guard let stored = snapshotStore.load(), stored.userID == userID else {
			return nil
		}
		return stored
	}

	private func appleCredentialRevoked(userID: String) async -> Bool {
		do {
			let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
			switch state {
			case .revoked, .notFound:
				return true
			case .authorized, .transferred:
				return false
			@unknown default:
				return false
			}
		} catch {
			return false
		}
	}

	private func store(_ snapshot: AuthLoginSnapshot) {
		loginSnapshot = snapshot
		isAuthenticated = true
		snapshotStore.save(snapshot)
		AppAnalytics.identifySignedInPlayer(userID: snapshot.userID, provider: snapshot.provider.rawValue)
	}

	private func clearSession() {
		loginSnapshot = nil
		isAuthenticated = false
		snapshotStore.clear()
	}

	private static func displayName(from name: PersonNameComponents?) -> String? {
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
		return parts.joined(separator: " ")
	}
}

enum AuthServiceError: LocalizedError {
	case missingAppleCredential
	case missingAppleUserID

	var errorDescription: String? {
		switch self {
		case .missingAppleCredential:
			"Apple did not return a valid authorization credential."
		case .missingAppleUserID:
			"Apple did not return a user identifier."
		}
	}
}

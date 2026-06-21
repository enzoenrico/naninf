//
//  AuthSessionStore.swift
//  magoSanduiche
//

import AuthenticationServices
import Foundation
import Supabase

@MainActor
@Observable
final class AuthSessionStore {
	private let snapshotStore: AuthLoginSnapshotStore
	private let authService: SupabaseAuthService?
	private var authListenerTask: Task<Void, Never>?
	private var hasStarted = false
	private var isUITestMode = false

	private(set) var loginSnapshot: AuthLoginSnapshot?
	private(set) var isAuthenticated = false
	private(set) var isLoadingSession = true
	private(set) var isAuthenticating = false
	private(set) var errorMessage: String?
	private(set) var configurationMessage: String?

	init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
		snapshotStore = AuthLoginSnapshotStore(defaults: defaults)
		loginSnapshot = snapshotStore.load()

		do {
			let configuration = try AppAuthConfiguration.load(bundle: bundle)
			authService = SupabaseAuthService(configuration: configuration)
		} catch {
			authService = nil
			configurationMessage = String(localized: "nan_auth_config_missing")
			isLoadingSession = false
		}
	}

	#if DEBUG
		/// Builds a store with a fixed, network-free state for UI-test screenshots.
		init(uiTestMode mode: UITestAuthMode, defaults: UserDefaults = .standard) {
			snapshotStore = AuthLoginSnapshotStore(defaults: defaults)
			authService = nil
			isUITestMode = true
			isLoadingSession = false

			switch mode {
			case .authenticated:
				loginSnapshot = AuthLoginSnapshot(
					uiTestUserID: "00000000-0000-0000-0000-000000000001",
					email: "wizard@mago.test",
					provider: .apple,
					displayName: "Sandwich Wizard"
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

		guard let authService else {
			isAuthenticated = false
			isLoadingSession = false
			return
		}

		authListenerTask = Task { @MainActor [weak self] in
			let changes = authService.authStateChanges
			for await (event, session) in changes {
				self?.handleAuthEvent(event, session: session)
			}
		}

		await refreshStoredSession()
	}

	func handleOpenURL(_ url: URL) {
		_ = authService?.handleOpenURL(url)
	}

	func handleAppleSignInButtonCompletion(_ result: Result<ASAuthorization, Error>) async {
		await authenticate(provider: .apple) { authService in
			try await authService.signInWithApple(result)
		}
	}

	func signIn(with provider: PlayerAuthProvider) async {
		switch provider {
		case .google:
			await authenticate(provider: .google) { authService in
				try await authService.signInWithGoogle()
			}
		case .apple, .unknown:
			break
		}
	}

	func signOut() async {
		isAuthenticating = true
		errorMessage = nil
		defer { isAuthenticating = false }

		do {
			try await authService?.signOut()
			clearSession()
			AppAnalytics.capture("auth_signed_out")
		} catch {
			errorMessage = error.localizedDescription
			AppAnalytics.capture("auth_sign_out_failed", properties: [
				"error": error.localizedDescription
			])
		}
	}

	private func refreshStoredSession() async {
		guard let authService else { return }
		isLoadingSession = true
		errorMessage = nil
		defer { isLoadingSession = false }

		do {
			let session = try await authService.currentSession()
			storeSession(session)
		} catch {
			clearSession()
		}
	}

	private func authenticate(
		provider: PlayerAuthProvider,
		operation: (SupabaseAuthService) async throws -> Session
	) async {
		guard let authService else { return }
		isAuthenticating = true
		errorMessage = nil
		defer { isAuthenticating = false }

		do {
			let session = try await operation(authService)
			storeSession(session, provider: provider)
			AppAnalytics.capture("auth_signed_in", properties: [
				"provider": provider.rawValue
			])
		} catch {
			errorMessage = error.localizedDescription
			AppAnalytics.capture("auth_sign_in_failed", properties: [
				"provider": provider.rawValue,
				"error": error.localizedDescription
			])
		}
	}

	private func handleAuthEvent(_ event: AuthChangeEvent, session: Session?) {
		switch event {
		case .initialSession, .signedIn, .tokenRefreshed, .userUpdated, .mfaChallengeVerified:
			if let session {
				storeSession(session)
			} else {
				clearSession()
			}
		case .signedOut, .userDeleted:
			clearSession()
		case .passwordRecovery:
			break
		}
		isLoadingSession = false
	}

	private func storeSession(_ session: Session, provider: PlayerAuthProvider? = nil) {
		let snapshot = AuthLoginSnapshot(session: session, provider: provider)
		loginSnapshot = snapshot
		isAuthenticated = true
		snapshotStore.save(snapshot)
	}

	private func clearSession() {
		loginSnapshot = nil
		isAuthenticated = false
		snapshotStore.clear()
	}
}

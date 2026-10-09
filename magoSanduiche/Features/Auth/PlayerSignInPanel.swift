//
//  PlayerSignInPanel.swift
//  magoSanduiche
//

import AuthenticationServices
import SwiftUI

struct PlayerSignInPanel: View {
	@Environment(AuthSessionStore.self) private var authSessionStore
	@Environment(\.colorScheme) private var colorScheme
	var onAuthenticated: () -> Void = {}

	var body: some View {
		SignInWithAppleButton(.signIn) { request in
			request.requestedScopes = [.fullName, .email]
		} onCompletion: { result in
			Task { @MainActor in
				await authSessionStore.handleAppleSignInButtonCompletion(result)
				guard authSessionStore.isAuthenticated else { return }
				onAuthenticated()
			}
		}
		.signInWithAppleButtonStyle(appleSignInButtonStyle)
		.frame(maxWidth: .infinity)
		.frame(height: 48)
		.disabled(isDisabled)
	}

	private var isDisabled: Bool {
		authSessionStore.isLoadingSession ||
			authSessionStore.isAuthenticating ||
			authSessionStore.configurationMessage != nil
	}

	private var appleSignInButtonStyle: SignInWithAppleButton.Style {
		switch colorScheme {
		case .light: .black
		case .dark: .white
		@unknown default: .black
		}
	}
}

//
//  PlayerSignInPanel.swift
//  magoSanduiche
//

import AuthenticationServices
import GoogleSignIn
import SwiftUI

struct PlayerSignInPanel: View {
	@Environment(AuthSessionStore.self) private var authSessionStore
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		VStack(spacing: 12) {
			SignInWithAppleButton(.signIn) { request in
				request.requestedScopes = [.fullName, .email]
			} onCompletion: { result in
				Task { @MainActor in
					await authSessionStore.handleAppleSignInButtonCompletion(result)
				}
			}
			.signInWithAppleButtonStyle(appleSignInButtonStyle)
			.frame(maxWidth: .infinity)
			.frame(height: 48)
			.disabled(isDisabled)

			GoogleSignInButtonRepresentable(
				colorScheme: colorScheme,
				isDisabled: isDisabled
			) {
				Task { @MainActor in
					await authSessionStore.signIn(with: .google)
				}
			}
			.frame(maxWidth: .infinity)
			.frame(height: 48)
			.disabled(isDisabled)
			.accessibilityLabel(Text("nan_auth_sign_in_google"))
		}
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

struct GoogleSignInButtonRepresentable: UIViewRepresentable {
	var colorScheme: ColorScheme
	var isDisabled: Bool
	var onTap: () -> Void

	func makeCoordinator() -> Coordinator {
		Coordinator(onTap: onTap)
	}

	func makeUIView(context: Context) -> GIDSignInButton {
		let button = GIDSignInButton()
		button.style = .wide
		button.colorScheme = mappedColorScheme
		button.addTarget(
			context.coordinator,
			action: #selector(Coordinator.handleTap),
			for: .touchUpInside
		)
		button.setContentHuggingPriority(.defaultLow, for: .horizontal)
		button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		return button
	}

	func updateUIView(_ button: GIDSignInButton, context: Context) {
		button.colorScheme = mappedColorScheme
		button.isEnabled = !isDisabled
		button.alpha = isDisabled ? 0.55 : 1.0
		context.coordinator.onTap = onTap
	}

	private var mappedColorScheme: GIDSignInButtonColorScheme {
		switch colorScheme {
		case .light: .light
		case .dark: .dark
		@unknown default: .light
		}
	}

	final class Coordinator {
		var onTap: () -> Void

		init(onTap: @escaping () -> Void) {
			self.onTap = onTap
		}

		@objc func handleTap() {
			onTap()
		}
	}
}

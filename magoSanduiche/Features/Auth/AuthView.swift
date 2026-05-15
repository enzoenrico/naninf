//
//  AuthView.swift
//  magoSanduiche
//

import AuthenticationServices
import GoogleSignIn
import SwiftUI

struct AuthView: View {
	@Environment(AuthSessionStore.self) private var authSessionStore
	@Environment(\.colorScheme) private var colorScheme

	private var isDisabled: Bool {
		authSessionStore.isLoadingSession ||
			authSessionStore.isAuthenticating ||
			authSessionStore.configurationMessage != nil
	}

	var body: some View {
		AppLayout(
			background: .gradient,
			contentPadding: EdgeInsets(top: Spacing.layoutTop, leading: 20, bottom: Spacing.layoutBottom, trailing: 20),
			scrollable: true
		) {
			CRTReveal {
				VStack(alignment: .leading, spacing: 18) {
					authHero
					statusPanel
					authActions
					footnote
				}
			}
		}
		.task {
			await authSessionStore.start()
		}
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private var appleSignInButtonStyle: SignInWithAppleButton.Style {
		switch colorScheme {
		case .light: .black
		case .dark: .white
		@unknown default: .black
		}
	}

	private var asciiForeground: Color {
		switch colorScheme {
		case .light: Color.primary.opacity(0.82)
		case .dark: Color.terminalMana
		@unknown default: Color.primary.opacity(0.82)
		}
	}

	private var asciiBackground: Color {
		Color.clear
	}

	private var authHero: some View {
		VStack(alignment: .leading, spacing: 12) {
			AsciiMediaView(catalogVideoNamed: "mageOpening")
				.asciiScaleMode(.fill)
				.asciiColumns(160)
				.asciiFontSize(7)
				.asciiColor(asciiForeground)
				.asciiBackground(asciiBackground)
				.frame(maxWidth: .infinity)
				.padding(.vertical, Spacing.sm)

			VStack(alignment: .leading, spacing: 10) {
				Text("nan_auth_hero_headline")
					.font(.monocraft(relativeTo: .title, weight: .bold))
					.foregroundStyle(Color.accent)
					.fixedSize(horizontal: false, vertical: true)

				CRTRevealText(
					text: String(localized: "nan_auth_hero_kicker"),
					font: .monocraft(relativeTo: .caption, weight: .semibold),
					color: .terminalMana,
					lineLimit: 2,
					delay: .milliseconds(220),
					showsCursorWhileTyping: true
				)
				.fixedSize(horizontal: false, vertical: true)

				VStack(alignment: .leading, spacing: 6) {
					Text("nan_auth_title")
						.font(.monocraft(relativeTo: .subheadline, weight: .semibold))
						.foregroundStyle(Color.accent.opacity(0.92))
						.fixedSize(horizontal: false, vertical: true)
					Text("nan_auth_subtitle")
						.font(.monocraft(relativeTo: .footnote, weight: .medium))
						.foregroundStyle(Color.terminalMutedText)
						.fixedSize(horizontal: false, vertical: true)
				}
				.padding(.top, 4)
			}
			.padding(.horizontal, Spacing.md)
			.padding(.bottom, Spacing.md)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.drawBorder(String(localized: "nan_auth_hero_border_title"), color: .accent, lineWidth: 1, animate: true)
	}

	@ViewBuilder
	private var statusPanel: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 8) {
				Text(statusTitle)
					.font(.monocraft(relativeTo: .caption, weight: .bold))
					.foregroundStyle(statusColor)
				if authSessionStore.isLoadingSession || authSessionStore.isAuthenticating {
					TerminalGlyphLoader(style: .blocks, textStyle: .caption, color: statusColor)
						.accessibilityHidden(true)
				}
				Spacer()
			}

			Text(statusBody)
				.font(.monocraft(relativeTo: .callout))
				.foregroundStyle(Color.terminalMutedText)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(14)
		.background(Color.terminalSurface)
		.drawBorder(String(localized: "nan_auth_status_panel"), color: statusColor, lineWidth: 1, animate: true)
	}

	private var authActions: some View {
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

	private var footnote: some View {
		Text("nan_auth_footnote")
			.font(.monocraft(relativeTo: .caption2, weight: .semibold))
			.foregroundStyle(Color.terminalMutedText)
			.fixedSize(horizontal: false, vertical: true)
			.padding(.bottom, Spacing.sm)
	}

	private var statusTitle: String {
		if authSessionStore.isLoadingSession {
			return String(localized: "nan_auth_status_checking")
		}
		if authSessionStore.isAuthenticating {
			return String(localized: "nan_auth_status_binding")
		}
		if authSessionStore.configurationMessage != nil {
			return String(localized: "nan_auth_status_config")
		}
		if authSessionStore.errorMessage != nil {
			return String(localized: "nan_auth_status_error")
		}
		return String(localized: "nan_auth_status_ready")
	}

	private var statusBody: String {
		if let configurationMessage = authSessionStore.configurationMessage {
			return configurationMessage
		}
		if let errorMessage = authSessionStore.errorMessage {
			return errorMessage
		}
		if authSessionStore.isLoadingSession {
			return String(localized: "nan_auth_body_checking")
		}
		if authSessionStore.isAuthenticating {
			return String(localized: "nan_auth_body_binding")
		}
		return String(localized: "nan_auth_body_ready")
	}

	private var statusColor: Color {
		if authSessionStore.configurationMessage != nil || authSessionStore.errorMessage != nil {
			return .terminalDanger
		}
		if authSessionStore.isLoadingSession || authSessionStore.isAuthenticating {
			return .terminalWarning
		}
		return .terminalMana
	}
}

private struct GoogleSignInButtonRepresentable: UIViewRepresentable {
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

#Preview {
	AuthView()
		.environment(AuthSessionStore())
}

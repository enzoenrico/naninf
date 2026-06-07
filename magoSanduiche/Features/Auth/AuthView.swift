//
//  AuthView.swift
//  magoSanduiche
//

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

	private var authHero: some View {
		VStack(alignment: .leading, spacing: 12) {
			AsciiMediaView(catalogVideoNamed: "mageOpening")
				.asciiScaleMode(.fill)
				.asciiColumns(160)
				.asciiFontSize(7)
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

	private var authActions: some View {
		PlayerSignInPanel()
			.disabled(isDisabled)
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

#Preview {
	AuthView()
		.environment(AuthSessionStore())
}

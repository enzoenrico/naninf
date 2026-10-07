//
//  PrivateCloudAccessGate.swift
//  magoSanduiche
//

import SwiftUI

struct PrivateCloudAccessGate: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Environment(AuthSessionStore.self) private var authSessionStore
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let reason: PCCUnavailability

	var body: some View {
		AppLayout(
			background: .gradient,
			contentPadding: EdgeInsets(top: Spacing.layoutTop, leading: 20, bottom: Spacing.layoutBottom, trailing: 20)
		) {
			CRTReveal {
				VStack(alignment: .leading, spacing: 18) {
					statusPanel
						.layoutPriority(1)
					Spacer(minLength: 0)
					subscribeButton
					signOutButton
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.onAppear {
			let reasonName = reason == .deviceNotEligible ? "device_not_eligible" : "system_not_ready"
			AppAnalytics.screen("Cloud access", properties: ["reason": reasonName])
			AppAnalytics.capture("cloud_access_blocked", properties: ["reason": reasonName])
		}
	}

	private var statusPanel: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(headline)
				.font(.monocraft(relativeTo: .title, weight: .bold))
				.foregroundStyle(Color.accent)
				.fixedSize(horizontal: false, vertical: true)

			Text(bodyText)
				.font(.monocraft(relativeTo: .footnote, weight: .medium))
				.foregroundStyle(Color.terminalMutedText)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(Spacing.md)
		.frame(maxWidth: .infinity, alignment: .leading)
		.drawBorder(String(localized: "nan_pcc_gate_border"), color: .accent, lineWidth: 1, animate: true)
	}

	private var subscribeButton: some View {
		Button {} label: {
			Text("nan_pcc_gate_subscribe")
				.font(.monocraft(relativeTo: .headline, weight: .semibold))
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
		}
		.buttonStyle(OnboardingPrimaryButtonStyle())
		.disabled(true)
		.accessibilityLabel(String(localized: "nan_pcc_gate_subscribe_a11y"))
	}

	private var signOutButton: some View {
		Button {
			Task { @MainActor in
				await authSessionStore.signOut()
				TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
					coordinator.popToRoot()
				}
			}
		} label: {
			HStack(spacing: 8) {
				Text("nan_profile_sign_out")
					.font(.monocraft(relativeTo: .headline, weight: .semibold))
				if authSessionStore.isAuthenticating {
					TerminalGlyphLoader(style: .blocks, textStyle: .caption, color: .terminalDanger)
						.accessibilityHidden(true)
				}
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
		}
		.buttonStyle(.plain)
		.foregroundStyle(Color.terminalDanger)
		.drawBorder(nil, color: .terminalDanger, lineWidth: 2)
		.opacity(authSessionStore.isAuthenticating ? 0.7 : 1)
		.disabled(authSessionStore.isAuthenticating)
		.accessibilityHint(String(localized: "nan_profile_sign_out_a11y"))
	}

	private var headline: String {
		switch reason {
		case .deviceNotEligible:
			String(localized: "nan_pcc_gate_headline_device")
		case .systemNotReady:
			String(localized: "nan_pcc_gate_headline_not_ready")
		}
	}

	private var bodyText: String {
		switch reason {
		case .deviceNotEligible:
			String(localized: "nan_dm_unavailable_device")
		case .systemNotReady:
			String(localized: "nan_dm_unavailable_not_ready")
		}
	}
}

#Preview {
	PrivateCloudAccessGate(reason: .deviceNotEligible)
		.environment(AppCoordinator())
		.environment(AuthSessionStore())
}

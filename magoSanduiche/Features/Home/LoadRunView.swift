//
//  LoadRunView.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI
import Foundation

struct LoadRunView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		AppLayout(background: .solid) {
			VStack(spacing: 18) {
				header

				emptyState

				Spacer(minLength: 0)

				backButton
			}
		}
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private var header: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("nan_load_header_kicker")
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(Color.terminalMana)
			Text("nan_load_title")
				.font(.monocraft(relativeTo: .title3, weight: .bold))
				.foregroundStyle(Color.accent)
				.fixedSize(horizontal: false, vertical: true)
			Text("nan_load_subtitle")
				.font(.monocraft(relativeTo: .callout))
				.foregroundStyle(Color.terminalMutedText)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var emptyState: some View {
		VStack(spacing: 14) {
			Text("nan_load_empty_headline")
				.font(.monocraft(relativeTo: .headline, weight: .bold))
				.foregroundStyle(Color.terminalWarning)

			HStack(spacing: 6) {
				Text("// scanning C:\\NAN\\SAVES")
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
					.foregroundStyle(Color.terminalMutedText)
				TerminalGlyphLoader(style: .dots, textStyle: .caption, color: .terminalMutedText)
					.accessibilityHidden(true)
			}

			Text("nan_load_empty_body")
				.font(.monocraft(relativeTo: .caption))
				.foregroundStyle(Color.terminalMutedText)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.vertical, Spacing.layoutBottom)
		.padding(.horizontal, Spacing.layoutLeading)
		.frame(maxWidth: .infinity)
		.background(Color.terminalSurface)
		.drawBorder(String(localized: "nan_load_panel_border"), color: .terminalWarning, lineWidth: 1)
	}

	private var backButton: some View {
		Button {
			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
				coordinator.back()
			}
		} label: {
			Text("nan_load_back")
				.font(.monocraft(relativeTo: .headline, weight: .semibold))
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
		}
		.buttonStyle(OnboardingPrimaryButtonStyle())
		.accessibilityHint(String(localized: "nan_load_back_a11y"))
	}
}

#Preview {
	LoadRunView()
		.environment(AppCoordinator())
}

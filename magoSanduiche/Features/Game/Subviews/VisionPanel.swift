//
//  VisionPanel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
	import UIKit
#endif

struct VisionPanel: View {
	let isCollapsed: Bool
	let isLoading: Bool
	let phase: GameUIPhase

	var body: some View {
		ZStack(alignment: .topLeading) {
			AsciiMediaView(catalogVideoNamed: "mageOpening")
				.asciiScaleMode(.fill)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.opacity(isLoading ? 0.55 : 1)

			Text(
				phase == .awaitingDungeonMaster
					? String(localized: "nan_vision_overlay_loading") : String(localized: "nan_vision_overlay_idle")
			)
			.font(.monocraft(relativeTo: .caption2))
			.foregroundStyle(Color.accent)
			.padding(10)

			if isLoading {
				VisionLoadingOverlay()
					.padding(10)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		.drawBorder(String(localized: "nan_vision_panel_title"), color: .terminalMana, lineWidth: 1)
		.clipped()
		.accessibilityLabel(
			isLoading
				? String(localized: "nan_vision_a11y_loading")
				: String(localized: "nan_vision_a11y_ready")
		)
		.accessibilityHint(String(localized: "nan_vision_a11y_hint_collapse"))
	}
}

private struct VisionLoadingOverlay: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 6) {
				Text(String(localized: "nan_vision_loading_title"))
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
				TerminalGlyphLoader(
					style: .blocks,
					textStyle: .caption2,
					weight: .bold,
					color: .terminalWarning
				)
			}
			.foregroundStyle(Color.terminalWarning)

			Text(String(localized: "nan_vision_loading_ram"))
				.font(.monocraft(relativeTo: .caption2))
				.foregroundStyle(Color.accent.opacity(0.72))
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 7)
		.background(Color.background.opacity(0.82))
		.drawBorder(nil, color: .terminalWarning.opacity(0.75), lineWidth: 1)
		.accessibilityHidden(true)
	}
}

struct CollapsedVisionBar: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack {
				Text(String(localized: "nan_vision_collapsed_title"))
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
				Spacer()
				Text("OPEN")
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
			}
			.foregroundStyle(Color.terminalMutedText)
			.padding(.horizontal, 10)
			.padding(.vertical, 10)
			.frame(maxWidth: .infinity)
		}
		.buttonStyle(.plain)
		.fixedSize(horizontal: false, vertical: true)
		.drawBorder(nil, color: Color.terminalMutedText.opacity(0.7), lineWidth: 1)
		.accessibilityLabel(String(localized: "nan_vision_collapsed_a11y"))
	}
}

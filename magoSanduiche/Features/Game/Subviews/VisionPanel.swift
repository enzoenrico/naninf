//
//  VisionPanel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct VisionPanel: View {
	let isCollapsed: Bool
	let isLoading: Bool
	let phase: GameUIPhase

	var body: some View {
		ZStack(alignment: .topLeading) {
			Image(.bread)
				.resizable()
				.interpolation(.none)
				.scaledToFit()
				.padding(24)
				.frame(maxWidth: .infinity)
				.frame(height: isCollapsed ? 0 : 220)
				.foregroundStyle(.accent)
				.opacity(isLoading ? 0.55 : 1)

				Text(phase == .awaitingDungeonMaster ? "rendering next omen" : "tap to collapse")
					.font(.monocraft(relativeTo: .caption2))
			.foregroundStyle(Color.accent)
			.padding(10)

			if isLoading {
				Rectangle()
					.fill(Color.accent.opacity(0.12))
					.frame(height: 24)
					.offset(y: 90)
					.blur(radius: 8)
			}
		}
		.frame(maxWidth: .infinity)
		.drawBorder("> Scene Feed", color: .terminalMana, lineWidth: 1)
		.clipped()
		.accessibilityLabel("Vision terminal")
		.accessibilityHint("Tap to collapse the scene panel")
	}
}

struct CollapsedVisionBar: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack {
				Text("> VISION TERMINAL COLLAPSED")
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
		.drawBorder(nil, color: Color.terminalMutedText.opacity(0.7), lineWidth: 1)
		.accessibilityLabel("Open vision terminal")
	}
}

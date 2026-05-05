//
//  TerminalStatusStrip.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct TerminalStatusStrip: View {
	let phase: GameUIPhase
	let isLoading: Bool

	var body: some View {
		HStack(spacing: 8) {
			Text(phase.statusLine)
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(statusColor)
				.lineLimit(1)
				.minimumScaleFactor(0.75)

			if isLoading {
				TerminalGlyphLoader(
					style: .spinner,
					textStyle: .caption,
					weight: .bold,
					color: .terminalWarning
				)
			}

			Spacer(minLength: 0)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(Color.terminalSurface)
		.drawBorder(nil, color: statusColor.opacity(0.8), lineWidth: 1)
	}

	private var statusColor: Color {
		switch phase {
		case .awaitingDungeonMaster, .rollingDice:
			.terminalWarning
		case .result:
			.terminalMana
		case .reading, .ready, .composing:
			.accent
		}
	}
}

struct InlineTerminalDots: View {
	var body: some View {
		TerminalGlyphLoader(
			style: .dots,
			textStyle: .caption,
			weight: .bold,
			color: .terminalWarning
		)
	}
}

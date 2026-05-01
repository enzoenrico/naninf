//
//  InlineResponseStatusRow.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct ResponseStatus: Identifiable, Equatable {
	let id = UUID()
	let phase: GameUIPhase
	let text: String
	let isTemporary: Bool

	init?(phase: GameUIPhase) {
		self.phase = phase
		switch phase {
		case .awaitingDungeonMaster:
			text = "> The dungeon master is thinking..."
			isTemporary = false
		case .result:
			text = "> Consequence received"
			isTemporary = true
		case .reading, .ready, .composing, .rollingDice:
			return nil
		}
	}

	var color: Color {
		switch phase {
		case .awaitingDungeonMaster:
			.terminalWarning
		case .result:
			.terminalMana
		case .reading, .ready, .composing, .rollingDice:
			.accent
		}
	}
}

struct InlineResponseStatusRow: View {
	let status: ResponseStatus
	let dismiss: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			Text(status.text)
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(status.color)
				.lineLimit(1)
				.minimumScaleFactor(0.75)

			if !status.isTemporary {
				InlineTerminalDots()
			}

			Spacer(minLength: 0)

//			if status.isTemporary {
//				Text("SWIPE")
//					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
//					.foregroundStyle(Color.terminalMutedText)
//			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(Color.terminalSurface)
		.drawBorder(nil, color: status.color.opacity(0.8), lineWidth: 1)
		.contentShape(Rectangle())
		.gesture(
			DragGesture(minimumDistance: 18)
				.onEnded { value in
					guard status.isTemporary else { return }
					let horizontalSwipe = abs(value.translation.width) > 36
					let upwardSwipe = value.translation.height < -18
					if horizontalSwipe || upwardSwipe {
						dismiss()
					}
				}
		)
		.accessibilityLabel(status.text.replacingOccurrences(of: "> ", with: ""))
		.accessibilityHint(status.isTemporary ? "Swipe to dismiss" : "Waiting for the dungeon master")
	}
}


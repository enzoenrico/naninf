//
//  InlineResponseStatusRow.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI
import Foundation

struct ResponseStatus: Identifiable, Equatable {
	let id = UUID()
	let phase: GameUIPhase
	let text: String
	let isTemporary: Bool

	init?(phase: GameUIPhase) {
		self.phase = phase
		switch phase {
		case .awaitingDungeonMaster:
			text = String(localized: "nan_phase_status_dm_thinking")
			isTemporary = false
		case .result:
			text = String(localized: "nan_phase_status_result")
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
		.accessibilityLabel(
			status.phase == .awaitingDungeonMaster
				? String(localized: "nan_inline_status_a11y_dm")
				: String(localized: "nan_inline_status_a11y_result")
		)
		.accessibilityHint(
			status.isTemporary
				? String(localized: "nan_inline_status_swipe_hint")
				: String(localized: "nan_inline_status_wait_hint")
		)
	}
}


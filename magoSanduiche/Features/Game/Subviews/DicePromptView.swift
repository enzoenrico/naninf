//
//  DicePromptView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct DicePromptView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let diceValue: Int
	let resultText: String
	let isRolling: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			TerminalStatusStrip(phase: .rollingDice, isLoading: isRolling)

			HStack(alignment: .center, spacing: 18) {
				Text("\(diceValue)")
					.font(.monocraft(relativeTo: .largeTitle, weight: .bold))
					.foregroundStyle(isRolling ? Color.terminalWarning : Color.accent)
					.monospacedDigit()
					.frame(width: 96, height: 96)
					.background(Color.terminalActiveSurface)
					.drawBorder(String(localized: "nan_dice_panel_title"), color: isRolling ? .terminalWarning : .accent, lineWidth: 2)
					.scaleEffect(isRolling && !reduceMotion ? 1.04 : 1)
					.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation), value: diceValue)

				VStack(alignment: .leading, spacing: 8) {
					Text(isRolling ? String(localized: "nan_dice_flavor_rolling") : String(localized: "nan_dice_flavor_idle"))
						.font(.monocraft(relativeTo: .headline, weight: .semibold))
						.foregroundStyle(Color.accent)
					Text(resultText)
						.font(.monocraft(relativeTo: .callout))
						.foregroundStyle(Color.terminalMutedText)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(12)
	}
}

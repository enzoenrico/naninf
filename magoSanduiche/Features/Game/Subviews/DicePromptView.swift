//
//  DicePromptView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct DicePromptView: View {
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
					.drawBorder("> D20", color: isRolling ? .terminalWarning : .accent, lineWidth: 2)
					.scaleEffect(isRolling ? 1.06 : 1)
					.animation(.easeInOut(duration: 0.12), value: diceValue)

				VStack(alignment: .leading, spacing: 8) {
					Text(isRolling ? "Fate is moving." : "Roll the dice, little wizard.")
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

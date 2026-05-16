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
	let revealStage: DiceRevealStage
	let resultText: String
	let showRollingFlavor: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(alignment: .center, spacing: 18) {
				Text("\(diceValue)")
					.font(.monocraft(relativeTo: .largeTitle, weight: .bold))
					.foregroundStyle(dieForegroundColor)
					.monospacedDigit()
					.frame(width: 96, height: 96)
					.background(Color.terminalActiveSurface)
					.drawBorder(
						String(localized: "nan_dice_panel_title"),
						color: dieBorderColor,
						lineWidth: 2,
						glowPreset: .subtle
					)
					.scaleEffect(dieScale)
					.opacity(dieOpacity)
					.animation(
						TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation), value: diceValue)

				VStack(alignment: .leading, spacing: 8) {
					Text(
						showRollingFlavor
							? String(localized: "nan_dice_flavor_rolling") : String(localized: "nan_dice_flavor_idle")
					)
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

	private var dieBorderColor: Color {
		switch revealStage {
		case .scrambling, .fadingOut, .suspense:
			return .terminalWarning
		case .idle, .bamReveal:
			return .accent
		}
	}

	private var dieForegroundColor: Color {
		switch revealStage {
		case .scrambling:
			return .terminalWarning
		case .fadingOut, .suspense:
			return .black
		case .idle, .bamReveal:
			return .accent
		}
	}

	private var dieOpacity: Double {
		switch revealStage {
		case .fadingOut, .suspense:
			return 0
		case .idle, .scrambling, .bamReveal:
			return 1
		}
	}

	private var dieScale: CGFloat {
		guard !reduceMotion else {
			switch revealStage {
			case .scrambling:
				return 1.04
			default:
				return 1
			}
		}
		switch revealStage {
		case .scrambling:
			return 1.04
		case .fadingOut:
			return reduceMotion ? 1 : 1.04
		case .suspense:
			return 0.93
		case .bamReveal:
			return 1
		case .idle:
			return 1
		}
	}
}

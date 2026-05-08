//
//  GameHeader.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

import SwiftUI

struct GameHeader: View {
	var onBack: (() -> Void)?
	var health: Int
	var mana: Int
	var maxHealth: Int
	var maxMana: Int
	var phase: GameUIPhase

	init(
		onBack: (() -> Void)? = nil,
		health: Int = 10,
		mana: Int = 14,
		maxHealth: Int = 18,
		maxMana: Int = 18,
		phase: GameUIPhase = .reading
	) {
		self.onBack = onBack
		self.health = health
		self.mana = mana
		self.maxHealth = maxHealth
		self.maxMana = maxMana
		self.phase = phase
	}

	var body: some View {
		VStack {
			HStack(alignment: .center, spacing: 8) {
				if let onBack {
					Button(action: onBack) {
						Text("> BACK")
							.font(.monocraft(relativeTo: .caption, weight: .semibold))
							.foregroundStyle(statusColor)
					}
					.buttonStyle(TerminalSubtleButtonStyle())
					.accessibilityLabel("Back to main menu")
				}
				VStack(alignment: .leading, spacing: 6) {
					AsciiProgressBar(.health, progress: health, maxProgress: maxHealth)
					AsciiProgressBar(.mana, progress: mana, maxProgress: maxMana)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.padding(8)
			.drawBorder(onBack == nil ? "> BACK" : nil, color: statusColor, lineWidth: 2)
			.accessibilityElement(children: .combine)
		}
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

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

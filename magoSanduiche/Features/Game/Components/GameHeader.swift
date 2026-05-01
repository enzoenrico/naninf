//
//  GameHeader.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

import SwiftUI

struct GameHeader: View {
	var health: Int
	var mana: Int
	var maxHealth: Int
	var maxMana: Int
	var phase: GameUIPhase

	init(
		health: Int = 10,
		mana: Int = 14,
		maxHealth: Int = 18,
		maxMana: Int = 18,
		phase: GameUIPhase = .reading
	) {
		self.health = health
		self.mana = mana
		self.maxHealth = maxHealth
		self.maxMana = maxMana
		self.phase = phase
	}

	var body: some View {
		HStack(alignment: .center, spacing: 8) {
			VStack {
				Image(.bread)
					.resizable()
					.padding()
					.scaledToFill()
					.foregroundStyle(.accent)
			}
			.frame(width: 64, height: 64)
			.background(Color.terminalSurface)
			.drawBorder(nil, lineWidth: 1)

			VStack(alignment: .leading, spacing: 6) {
				Text("> DUNGEON LINK ACTIVE")
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
					.foregroundStyle(statusColor)
					.lineLimit(1)
					.minimumScaleFactor(0.75)
				AsciiProgressBar(.health, progress: health, maxProgress: maxHealth)
				AsciiProgressBar(.mana, progress: mana, maxProgress: maxMana)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(8)
		.drawBorder(color: statusColor, lineWidth: 2)
		.accessibilityElement(children: .combine)
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

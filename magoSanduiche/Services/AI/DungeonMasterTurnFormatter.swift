//
//  DungeonMasterTurnFormatter.swift
//  magoSanduiche
//

import Foundation

enum DungeonMasterTurnKind: String, Sendable {
	case playerText
	case diceResultConfirmation
}

struct DungeonMasterTurnContext: Sendable {
	let kind: DungeonMasterTurnKind
	let playerMessage: String
	let health: Int
	let maxHealth: Int
	let mana: Int
	let maxMana: Int
	let storySoFar: [TerminalEntry]
	let diceRoll: Int?
}

enum DungeonMasterTurnFormatter {
	static let storyCharacterBudget = 8_000

	static func format(_ context: DungeonMasterTurnContext) -> String {
		var lines: [String] = [
			"turnKind: \(context.kind.rawValue)",
			"health: \(context.health)/\(context.maxHealth)",
			"mana: \(context.mana)/\(context.maxMana)",
		]

		let story = storyLines(from: context.storySoFar, budget: storyCharacterBudget)
		if !story.isEmpty {
			lines.append("story:")
			lines.append(contentsOf: story)
		}

		switch context.kind {
		case .playerText:
			lines.append("playerMessage: \(context.playerMessage)")
		case .diceResultConfirmation:
			if let roll = context.diceRoll {
				lines.append("playerD20Roll: \(roll)")
			}
			lines.append(
				"instruction: The player confirmed their d20 roll in the UI. Adjudicate the pending check using playerD20Roll. "
					+ "Set healthChange and manaChange when those resources change. Set nextInput to write and provide exactly three options "
					+ "unless another dice roll is required, then set nextInput to roll. Do not resolve a new roll yourself."
			)
		}

		return lines.joined(separator: "\n")
	}

	static func storyLines(from entries: [TerminalEntry], budget: Int) -> [String] {
		var chosenReversed: [String] = []
		var used = 0

		for entry in entries.reversed() {
			guard entry.kind == .player || entry.kind == .dungeonMaster else { continue }
			let speaker = entry.kind == .player ? "Mage" : "DM"
			var line = "\(speaker): \(entry.text)"
			if line.count > budget {
				line = String(line.suffix(budget))
			}

			let separator = chosenReversed.isEmpty ? 0 : 1
			if used + separator + line.count > budget {
				if chosenReversed.isEmpty {
					chosenReversed.append(line)
				}
				break
			}

			chosenReversed.append(line)
			used += separator + line.count
		}

		return Array(chosenReversed.reversed())
	}
}

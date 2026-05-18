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
	let latestDungeonMasterExcerpt: String?
	let diceRoll: Int?
	let diceOutcomeSummary: String?
}

enum DungeonMasterTurnFormatter {
	private static let excerptMaxLength = 400

	static func format(_ context: DungeonMasterTurnContext) -> String {
		var lines: [String] = [
			"turnKind: \(context.kind.rawValue)",
			"health: \(context.health)/\(context.maxHealth)",
			"mana: \(context.mana)/\(context.maxMana)",
		]

		if let excerpt = trimmedExcerpt(context.latestDungeonMasterExcerpt) {
			lines.append("latestDungeonMasterExcerpt: \(excerpt)")
		}

		switch context.kind {
		case .playerText:
			lines.append("playerMessage: \(context.playerMessage)")
		case .diceResultConfirmation:
			if let roll = context.diceRoll {
				lines.append("playerD20Roll: \(roll)")
			}
			if let summary = context.diceOutcomeSummary, !summary.isEmpty {
				lines.append("rollOutcomeSummary: \(summary)")
			}
			lines.append(
				"instruction: The player confirmed their d20 roll in the UI. Adjudicate the pending check from your last turn using this roll. "
					+ "The app does not change HP or MP from the roll alone — use changeHealth in the tool phase when stats should change. "
					+ "Call decideAction with action 0 and provide exactly three options in the final JSON unless another dice roll is required (then action 1)."
			)
		}

		return lines.joined(separator: "\n")
	}

	private static func trimmedExcerpt(_ text: String?) -> String? {
		guard let text else { return nil }
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		if trimmed.count <= excerptMaxLength {
			return trimmed
		}
		return String(trimmed.suffix(excerptMaxLength))
	}
}

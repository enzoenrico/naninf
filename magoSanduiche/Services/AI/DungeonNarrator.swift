//
//  DungeonNarrator.swift
//  magoSanduiche
//

import Foundation
import FoundationModels

protocol DungeonNarrator {
	func draft(
		for prompt: String,
		analyticsContext: AIAnalyticsContext?
	) async throws(DungeonMasterError) -> DungeonTurnDraft
}

@Generable(description: "One dungeon master turn for a solo dark-fantasy RPG.")
nonisolated struct DungeonTurnDraft: Equatable {
	@Guide(description: "The story. One to four short paragraphs, each starting with `>`. Outcome, new situation, immediate stakes.")
	var narrative: String

	@Guide(description: "Signed HP change caused by this turn. Negative damages, positive heals. Glancing -1 to -3, solid -4 to -8, deadly -9 or worse. 0 when HP does not change.", .range(-40...40))
	var healthChange: Int

	@Guide(description: "Signed mana change. Cantrip -1, standard spell -2 to -3, ritual -4 or worse. Restores +2 to +6. 0 when no magic was spent or regained. If a cast would go below 0 the spell fizzles and this is 0.", .range(-30...30))
	var manaChange: Int

	@Guide(description: "What the player does next. write for free text with three options. roll when an uncertain, meaningful outcome needs a d20 in the UI. Never resolve the roll yourself.")
	var nextInput: NextInput

	@Guide(description: "Three short, distinct tactical choices. No letter or number prefixes.", .count(3))
	var options: [String]

	@Guide(description: "One dense literal sentence describing what the Mage sees now, for image generation. Empty string when nothing is visible.")
	var visualPrompt: String
}

@Generable
nonisolated enum NextInput: Equatable {
	case write
	case roll

	var gameAction: GameAction {
		switch self {
		case .write:
			.write
		case .roll:
			.roll
		}
	}
}

extension DungeonTurnDraft {
	static let healthRange = -40...40
	static let manaRange = -30...30

	func resolved() -> DungeonMasterTurn {
		let health = clamped(healthChange, to: Self.healthRange)
		let mana = clamped(manaChange, to: Self.manaRange)

		var toolEffects: [GameToolEffect] = []
		if health != 0 {
			toolEffects.append(.changeHealth(health))
		}
		if mana != 0 {
			toolEffects.append(.changeMana(mana))
		}
		toolEffects.append(.requestAction(nextInput.gameAction))

		let trimmedVisual = visualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
		let output = PromptOutput(
			narrative: narrative,
			toolResults: "",
			options: DungeonMasterTurnValidation.paddedOptions(from: options),
			visualPrompt: trimmedVisual.isEmpty ? nil : trimmedVisual
		)
		return DungeonMasterTurn(output: output, toolEffects: toolEffects)
	}

	private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
		min(range.upperBound, max(range.lowerBound, value))
	}
}

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

@Generable(description: "One turn of a fictional tabletop fantasy game. When the prompt includes playerD20Roll, narrate that result's effect on pendingCheck.")
nonisolated struct DungeonTurnDraft: Equatable {
	@Guide(description: "The story. One to four short paragraphs, each starting with `>`. Brief adventure tension. When playerD20Roll is present, this is the outcome of that result for pendingCheck. Otherwise leave any d20 number to the UI.")
	var narrative: String

	@Guide(description: "Signed hit-point change for this turn. Negative lowers HP, positive restores it. Graze -1 to -3, solid blow -4 to -8, dire blow -9 or worse. 0 when HP stays the same.", .range(-40...40))
	var healthChange: Int

	@Guide(description: "Signed mana change. Cantrip -1, standard spell -2 to -3, ritual -4 or worse. Restores +2 to +6. 0 when no magic was spent or regained. If a cast would go below 0 the spell fizzles and this is 0.", .range(-30...30))
	var manaChange: Int

	@Guide(description: "What the player does next. write, with three options, after a resolved beat, including after playerD20Roll settles pendingCheck. roll only to request a new d20 in the UI; leave that number unstated.")
	var nextInput: NextInput

	@Guide(description: "Three short, distinct tactical choices. No letter or number prefixes.", .count(3))
	var options: [String]

	@Guide(description: "The shot to paint. A moving, high-contrast moment. Leave poseOrAction empty when nothing is visible.")
	var scene: SceneDirection
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

		let output = PromptOutput(
			narrative: narrative,
			options: options,
			scene: scene.illustrated
		)
		return DungeonMasterTurn(output: output, toolEffects: toolEffects)
	}

	private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
		min(range.upperBound, max(range.lowerBound, value))
	}
}

//
//  DecideAction.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 11/12/25.
//

import Foundation

nonisolated struct DecideActionTool: ModelTool {
	static let name = "decideAction"
	static let description = """
		Chooses the player's next input mode and MUST be called once on every turn, during the tool phase, \
		before the final JSON. Use action 0 for free-text input (the normal case: the player types or taps one \
		of the three suggested options). Use action 1 only when the outcome is uncertain and meaningful and the \
		Mage must physically roll a d20 in the UI before the story can continue — build the tension and state the \
		stakes, but do not resolve the roll yourself.
		"""

	static let parameters = ToolParameterSchema(
		integerFields: [
			ToolIntegerParameter(
				name: "action",
				description: """
					The next input mode. Use 0 for text input (default, with three suggested options) and 1 to \
					require a player-facing d20 dice roll in the UI.
					""",
				minimum: 0,
				maximum: 1,
				defaultValue: 0
			)
		]
	)

	struct Arguments: Codable, Sendable {
		let action: Int
	}

	struct Result: ModelToolResult {
		let action: GameAction

		var modelMessage: String {
			switch action {
			case .write:
				"Action requested: text input. UI should show the text input interface."
			case .roll:
				"Action requested: dice roll. UI should show the dice roll interface."
			}
		}

		var effects: [GameToolEffect] {
			[.requestAction(action)]
		}
	}

	static func call(arguments: Arguments) async throws -> Result {
		let action: GameAction = arguments.action == 1 ? .roll : .write
		return Result(action: action)
	}
}

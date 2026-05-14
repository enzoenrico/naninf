//
//  DecideAction.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 11/12/25.
//

import Foundation

nonisolated struct DecideActionTool: ModelTool {
	static let name = "decideAction"
	static let description = "Choose the next player input type. Use 0 for text input and 1 for dice roll."

	static let parameters = ToolParameterSchema(
		integerFields: [
			ToolIntegerParameter(
				name: "action",
				description: "The next input mode. Use 0 for text input and 1 for dice roll.",
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

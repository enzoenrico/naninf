//
//  ChangeHealth.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 11/12/25.
//

import Foundation

nonisolated struct ChangeHealthTool: ModelTool {
	static let name = "changeHealth"
	static let description =
		"Changes the player's health value. Use positive amounts to heal and negative amounts for damage. Range: -40 to 40."

	static let parameters = ToolParameterSchema(
		integerFields: [
			ToolIntegerParameter(
				name: "amount",
				description: "The health delta. Positive values heal, negative values damage, and zero leaves health unchanged.",
				minimum: -40,
				maximum: 40,
				defaultValue: -5
			)
		]
	)

	struct Arguments: Codable, Sendable {
		let amount: Int
	}

	struct Result: ModelToolResult {
		let amount: Int

		var modelMessage: String {
			switch amount {
			case let value where value > 0:
				"Health increased by \(value)"
			case let value where value < 0:
				"Health decreased by \(abs(value))"
			default:
				"Health unchanged"
			}
		}

		var effects: [GameToolEffect] {
			[.changeHealth(amount)]
		}
	}

	static func call(arguments: Arguments) async throws -> Result {
		let amount = min(max(arguments.amount, -40), 40)
		return Result(amount: amount)
	}
}

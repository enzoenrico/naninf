//
//  ChangeHealth.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 11/12/25.
//

import Foundation

nonisolated struct ChangeHealthTool: ModelTool {
	static let name = "changeHealth"
	static let description = """
		Changes the Mage's health (HP). This is the ONLY way HP ever moves; narrating a wound, heal, trap, or \
		poison does nothing on its own — you MUST call this tool whenever HP should change. Negative amount deals \
		damage, positive amount heals. Keep magnitudes proportional to the fiction: glancing harm -1 to -3, a \
		solid hit -4 to -8, severe or deadly danger -9 or worse; healing follows the same bands. Do not change HP \
		for mere tension or fatigue — narrate those without calling this tool. The app clamps the result to the \
		valid range. Range: -40 to 40.
		"""

	static let parameters = ToolParameterSchema(
		integerFields: [
			ToolIntegerParameter(
				name: "amount",
				description: """
					The signed health delta. Negative values damage (glancing -1 to -3, solid -4 to -8, deadly \
					-9+), positive values heal by the same bands, and zero leaves health unchanged.
					""",
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


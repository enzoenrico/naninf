//
//  ChangeMana.swift
//  magoSanduiche
//
//  Created by Cursor on 20/06/26.
//

import Foundation

nonisolated struct ChangeManaTool: ModelTool {
	static let name = "changeMana"
	static let description = """
		Changes the Mage's mana (MP). This is the ONLY way mana ever moves; narration alone never spends or \
		restores it. Use a negative amount to spend mana on a spell and a positive amount to restore it. \
		Spell costs: cantrips/minor utility -1, standard combat or utility spell -2 to -3, powerful or ritual \
		spell -4 or worse. Restore with potions, resting, ley-line nodes, or arcane rewards: small +2 to +5, \
		large +6 or more. If the spend would push mana below 0 the spell fizzles — do not narrate a successful \
		cast. The app clamps the result to the valid range. Range: -30 to 30.
		"""

	static let parameters = ToolParameterSchema(
		integerFields: [
			ToolIntegerParameter(
				name: "amount",
				description: """
					The signed mana delta. Negative spends mana on a cast (cantrip -1, standard -2 to -3, \
					powerful -4+), positive restores it (potion/rest +2 to +6), and zero leaves mana unchanged.
					""",
				minimum: -30,
				maximum: 30,
				defaultValue: -2
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
				"Mana restored by \(value)"
			case let value where value < 0:
				"Mana spent: \(abs(value))"
			default:
				"Mana unchanged"
			}
		}

		var effects: [GameToolEffect] {
			[.changeMana(amount)]
		}
	}

	static func call(arguments: Arguments) async throws -> Result {
		let amount = min(max(arguments.amount, -30), 30)
		return Result(amount: amount)
	}
}

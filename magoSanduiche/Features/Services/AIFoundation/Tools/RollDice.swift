//
//  RollDice.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation
import OpenAI

struct RollDiceTool: ExecutableTool {
	static let name = "rollDice"

	static let definition = ChatQuery.ChatCompletionToolParam(
		function: .init(
			name: name,
			description:
				"Rolls a dice, getting a number between 0 - x, for the action to act accordingly, basing the number for the actions success, damage, etc..."
		)
	)

	struct Arguments: Codable {
		let faces: Int
	}

	static func execute(arguments: String) async throws -> String {
		let decoder = JSONDecoder()
		guard let data = arguments.data(using: .utf8) else {
			return "Error: Invalid arguments"
		}

		let args = try decoder.decode(Arguments.self, from: data)
		let clampedFaces = max(args.faces, 0)
		let diceRoll = Int.random(in: 0...clampedFaces)

		return "Rolled a d\(clampedFaces): \(diceRoll)"
	}
}

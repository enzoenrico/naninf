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
				"Rolls a die and returns a random value between 1 and the requested number of faces."
		)
	)

	struct Arguments: Codable {
		let faces: Int
	}

	static func execute(arguments: String) async throws -> String {
		guard let data = arguments.data(using: .utf8) else {
			return "Error: Invalid arguments"
		}

		let args = try JSONDecoder().decode(Arguments.self, from: data)
		let faces = max(args.faces, 1)
		let diceRoll = Int.random(in: 1...faces)

		return "Rolled a d\(faces): \(diceRoll)"
	}
}

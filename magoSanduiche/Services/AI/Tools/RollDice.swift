//
//  RollDice.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation

nonisolated struct RollDiceTool: ModelTool {
	static let name = "rollDice"
	static let description = "Rolls a die and returns a random value between 1 and the requested number of faces."

	static let parameters = ToolParameterSchema(
		integerFields: [
			ToolIntegerParameter(
				name: "faces",
				description: "The number of faces on the die. Use 20 for a standard d20 roll.",
				minimum: 1,
				maximum: 100,
				defaultValue: 20
			)
		]
	)

	struct Arguments: Codable, Sendable {
		let faces: Int
	}

	struct Result: ModelToolResult {
		let faces: Int
		let value: Int

		var modelMessage: String {
			"Rolled a d\(faces): \(value)"
		}
	}

	static func call(arguments: Arguments) async throws -> Result {
		let faces = max(arguments.faces, 1)
		let diceRoll = Int.random(in: 1...faces)

		return Result(faces: faces, value: diceRoll)
	}
}

//
//  RollDice.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation
import FoundationModels

struct RollDice: Tool {
	let name = "rollDice"
	let description =
		"Rolls a dice, getting a number between 0 - x, for the action to act accordingly, basing the number for the actions success, damage, etc..."

	@Generable
	struct Arguments {
		@Guide(
			description: "The number of faces the dice will have, the dice will roll from 0 up to faces", .range(6...20)
		)
		let faces: Int
	}

	func call(arguments: Arguments) async throws -> Int {
		let diceRoll = Int.random(in: 0...arguments.faces)
        print(diceRoll)
		return diceRoll
	}
}

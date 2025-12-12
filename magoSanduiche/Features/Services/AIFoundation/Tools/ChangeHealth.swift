//
//  ChangeHealth.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 11/12/25.
//

import Foundation
import FoundationModels

struct ChangeHealth: Tool {
	let name = "changeHealth"
	let description =
		"Changes the player's health's value, this should be used when the player loses or gain's health, for example, if fighting and taking damage, the player should lose health, if the player takes a healing potion, the player should get health back"

	@Generable
	struct Arguments {
		@Guide(
			description: "The amount of health that will be changed", .range(1...40)
		)
		let faces: Int
	}

	func call(arguments: Arguments) async throws -> Int {
		let diceRoll = Int.random(in: 0...arguments.faces)
		return diceRoll
	}
}

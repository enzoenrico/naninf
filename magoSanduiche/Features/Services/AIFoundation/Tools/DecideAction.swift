////
////  DecideAction.swift
////  magoSanduiche
////
////  Created by Enzo Enrico on 11/12/25.
////

import Foundation
import FoundationModels

struct DecideAction: Tool {
	let name = "decideAction"
	let description =
		"When a player input is needed, if this input is a dice roll or a action input as text, you must decide and call this tool to make the action screen pop up to the player."

	let onActionRequested: (Int) -> Void

	init(onActionRequested: @escaping (Int) -> Void) {
		self.onActionRequested = onActionRequested
	}

	@Generable
	struct Arguments {
		@Guide(
			description: "If the player must roll a dice or submit text input, use the number 0 for text input and the number 1 for rolling the dice"
		)
		let action: Int 
	}

	func call(arguments: Arguments) async throws -> Int {
		onActionRequested(arguments.action)
		return 1
	}
}

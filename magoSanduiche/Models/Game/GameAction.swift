//
//  GameAction.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

enum GameAction {
	case write
	case roll

	func buttonTitle(isInputVisible: Bool) -> String {
		switch self {
		case .write:
			isInputVisible ? "> SEND COMMAND" : "> WRITE COMMAND"
		case .roll:
			"> ROLL D20"
		}
	}

	var buttonImage: Icons {
		switch self {
		case .write:
			.ink
		case .roll:
			.dice
		}
	}
}

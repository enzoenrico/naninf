//
//  GameAction.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

import Foundation

enum GameAction: Sendable {
	case write
	case roll

	func buttonTitle(isInputVisible: Bool) -> String {
		switch self {
		case .write:
			isInputVisible
				? String(localized: "nan_action_send_command") : String(localized: "nan_action_write_command")
		case .roll:
			String(localized: "nan_action_roll_d20")
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

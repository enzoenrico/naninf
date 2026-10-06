//
//  GameToolEffect.swift
//  magoSanduiche
//

import Foundation

nonisolated enum GameToolEffect: Sendable, Equatable, CustomStringConvertible {
	case requestAction(GameAction)
	case changeHealth(Int)
	case changeMana(Int)

	var description: String {
		switch self {
		case .requestAction(.write):
			"requestAction(write)"
		case .requestAction(.roll):
			"requestAction(roll)"
		case .changeHealth(let amount):
			"changeHealth(\(amount))"
		case .changeMana(let amount):
			"changeMana(\(amount))"
		}
	}
}

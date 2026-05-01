//
//  GameUIPhase.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.
//

enum GameUIPhase: Equatable {
	case reading
	case ready
	case composing
	case awaitingDungeonMaster
	case rollingDice
	case result

	var statusLine: String {
		switch self {
		case .reading:
			"> BOOTING DUNGEON SESSION"
		case .ready:
			"> AWAITING PLAYER INPUT"
		case .composing:
			"> COMPOSE YOUR NEXT COMMAND"
		case .awaitingDungeonMaster:
			"> The dungeon master is thinking..."
		case .rollingDice:
			"> FATE ENGINE SPINNING"
		case .result:
			"> Consequence received"
		}
	}

	var actionTitle: String {
		switch self {
		case .reading:
			"> Transmission"
		case .ready:
			"> Command Line"
		case .composing:
			"> Write Command"
		case .awaitingDungeonMaster:
			"> Processing"
		case .rollingDice:
			"> Roll Check"
		case .result:
			"> Dungeon Log"
		}
	}
}

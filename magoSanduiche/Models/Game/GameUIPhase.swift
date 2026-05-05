//
//  GameUIPhase.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.
//

import Foundation

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
			String(localized: "nan_phase_status_reading")
		case .ready:
			String(localized: "nan_phase_status_ready")
		case .composing:
			String(localized: "nan_phase_status_composing")
		case .awaitingDungeonMaster:
			String(localized: "nan_phase_status_dm_thinking")
		case .rollingDice:
			String(localized: "nan_phase_status_rolling")
		case .result:
			String(localized: "nan_phase_status_result")
		}
	}

	var actionTitle: String {
		switch self {
		case .reading:
			String(localized: "nan_phase_action_reading")
		case .ready:
			String(localized: "nan_phase_action_ready")
		case .composing:
			String(localized: "nan_phase_action_composing")
		case .awaitingDungeonMaster:
			String(localized: "nan_phase_action_processing")
		case .rollingDice:
			String(localized: "nan_phase_action_roll_check")
		case .result:
			String(localized: "nan_phase_action_result")
		}
	}
}

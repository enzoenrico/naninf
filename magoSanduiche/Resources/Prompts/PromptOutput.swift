//
//  PromptOutput.swift
//  magoSanduiche
//

import Foundation

nonisolated struct PromptOutput: Sendable, Equatable {
	let narrative: String
	let options: [String]
	let scene: SceneDirection?

	init(narrative: String, options: [String], scene: SceneDirection?) {
		self.narrative = narrative
		self.options = DungeonMasterTurnValidation.paddedOptions(from: options)
		self.scene = scene
	}
}

nonisolated struct DungeonMasterTurn: Sendable, Equatable {
	let output: PromptOutput
	let toolEffects: [GameToolEffect]
}

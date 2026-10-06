//
//  PromptOutput.swift
//  magoSanduiche
//

import Foundation

nonisolated struct PromptOutput: Sendable, Equatable {
	let narrative: String
	let options: [String]
	let visualPrompt: String?

	init(narrative: String, options: [String], visualPrompt: String?) {
		self.narrative = narrative
		self.options = DungeonMasterTurnValidation.paddedOptions(from: options)
		let trimmed = visualPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		self.visualPrompt = trimmed.isEmpty ? nil : trimmed
	}
}

nonisolated struct DungeonMasterTurn: Sendable, Equatable {
	let output: PromptOutput
	let toolEffects: [GameToolEffect]
}

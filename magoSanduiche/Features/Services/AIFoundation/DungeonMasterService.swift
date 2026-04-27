//
//  DungeonMasterService.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation
import OpenAI

enum AIAvailabilityErrors: Error {
	case unavailable(String)
}

@MainActor
class DungeonMasterService {
	private let service: OpenAIService
	private let actionCallback: ((Int) -> Void)?

	init(actionCallback: ((Int) -> Void)? = nil) throws {
		self.actionCallback = actionCallback

		// Set up the action callback on the tool
		DecideActionTool.onActionRequested = actionCallback

		// TODO: Move API key to secure storage
		let apiKey =
			"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"

		self.service = OpenAIService(
			apiKey: apiKey,
			instructions: Prompts.systemPrompt
		)
	}

	// MARK: - Generation

	/// Generate a dungeon master response for the given scenario.
	/// Returns a typed `PromptOutput` struct, not raw JSON.
	public func generate(_ scenario: String) async throws -> PromptOutput {
		do {
			let response = try await service.generate(
				scenario,
				returning: PromptOutput.self,
				tools: [RollDiceTool.self, DecideActionTool.self, ChangeHealthTool.self],
				model: .gpt4_o_mini
			)
			print(response)
			return response
		} catch {
			print(error.localizedDescription)
			throw error
		}
	}

	/// Clear the conversation history for a fresh start.
	public func clearHistory() {
		service.clearHistory()
	}
}

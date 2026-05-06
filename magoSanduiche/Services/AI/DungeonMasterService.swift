//
//  DungeonMasterService.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation
import OpenAI

enum AIAvailabilityErrors: Error, LocalizedError {
	case unavailable(String)

	var errorDescription: String? {
		switch self {
		case .unavailable(let message):
			message
		}
	}
}

@MainActor
final class DungeonMasterService {
	private let service: OpenAIService

	init(actionCallback: ((Int) -> Void)? = nil) throws {
		DecideActionTool.onActionRequested = actionCallback

		guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
			!apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		else {
			throw AIAvailabilityErrors.unavailable("Missing OPENAI_API_KEY in Info.plist")
		}

		self.service = OpenAIService(
			apiKey: apiKey,
			instructions: Prompts.systemPrompt
		)
	}

	func generate(_ scenario: String, analyticsContext: AIAnalyticsContext? = nil) async throws -> PromptOutput {
		try await service.generate(
			scenario,
			returning: PromptOutput.self,
			tools: [RollDiceTool.self, DecideActionTool.self, ChangeHealthTool.self],
			model: .gpt4_o_mini,
			analyticsContext: analyticsContext
		)
	}

	func clearHistory() {
		service.clearHistory()
	}
}

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
protocol DungeonMasterModelClient: AnyObject {
	func generateDungeonTurn(
		_ scenario: String,
		tools: [AnyModelTool],
		model: Model,
		analyticsContext: AIAnalyticsContext?
	) async throws -> AITurnResult<PromptOutput>

	func clearHistory()
}

extension OpenAIService: DungeonMasterModelClient {
	func generateDungeonTurn(
		_ scenario: String,
		tools: [AnyModelTool],
		model: Model,
		analyticsContext: AIAnalyticsContext?
	) async throws -> AITurnResult<PromptOutput> {
		try await generate(
			scenario,
			returning: PromptOutput.self,
			tools: tools,
			model: model,
			analyticsContext: analyticsContext
		)
	}
}

@MainActor
final class DungeonMasterService {
	@MainActor
	static var modelTools: [AnyModelTool] {
		[
			AnyModelTool(RollDiceTool.self),
			AnyModelTool(DecideActionTool.self),
			AnyModelTool(ChangeHealthTool.self),
		]
	}

	private let service: any DungeonMasterModelClient

	init() throws {
		#if DEBUG
			if OpenAIService.isDebugStubBypassingNetwork {
				self.service = OpenAIService(
					apiKey: "debug-stub",
					instructions: Prompts.systemPrompt
				)
				return
			}
		#endif

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

	func generate(_ scenario: String, analyticsContext: AIAnalyticsContext? = nil) async throws -> AITurnResult<PromptOutput> {
		try await service.generateDungeonTurn(
			scenario,
			tools: Self.modelTools,
			model: .gpt4_o_mini,
			analyticsContext: analyticsContext
		)
	}

	func clearHistory() {
		service.clearHistory()
	}
}

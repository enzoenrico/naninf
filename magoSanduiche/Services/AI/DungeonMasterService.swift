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

nonisolated enum DungeonMasterTurnValidation {
	static let minimumOptionCount = 3

	static let fallbackOptions: [String] = [
		String(localized: "nan_dm_fallback_option_explore"),
		String(localized: "nan_dm_fallback_option_observe"),
		String(localized: "nan_dm_fallback_option_caution"),
	]

	static func normalizedOptions(from options: [String]) -> [String] {
		options
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}

	static func paddedOptions(from options: [String]) -> [String] {
		var result = normalizedOptions(from: options)
		guard result.count < minimumOptionCount else {
			return Array(result.prefix(minimumOptionCount))
		}

		for fallback in fallbackOptions where result.count < minimumOptionCount {
			if !result.contains(fallback) {
				result.append(fallback)
			}
		}

		while result.count < minimumOptionCount {
			result.append(
				String(
					format: String(localized: "nan_dm_fallback_option_generic"),
					result.count + 1
				)
			)
		}

		return Array(result.prefix(minimumOptionCount))
	}

	static func hasRequestAction(in effects: [GameToolEffect]) -> Bool {
		effects.contains {
			if case .requestAction = $0 { return true }
			return false
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

	func generateSceneImage(
		prompt: String,
		analyticsContext: AIAnalyticsContext?
	) async throws -> URL
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
	/// Player-facing rolls use the dice UI + `diceResultConfirmation` turns, not `rollDice`.
	static var modelTools: [AnyModelTool] {
		[
			AnyModelTool(DecideActionTool.self),
			AnyModelTool(ChangeHealthTool.self),
			AnyModelTool(ChangeManaTool.self),
		]
	}

	func generate(
		context: DungeonMasterTurnContext,
		analyticsContext: AIAnalyticsContext? = nil
	) async throws -> AITurnResult<PromptOutput> {
		try await generate(
			DungeonMasterTurnFormatter.format(context),
			analyticsContext: analyticsContext
		)
	}

	private let service: any DungeonMasterModelClient

	init(modelClient: any DungeonMasterModelClient) {
		self.service = modelClient
	}

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
		let turn = try await service.generateDungeonTurn(
			scenario,
			tools: Self.modelTools,
			model: .gpt4_o_mini,
			analyticsContext: analyticsContext
		)
		return validateTurn(turn, analyticsContext: analyticsContext)
	}

	func clearHistory() {
		service.clearHistory()
	}

	func generateSceneMedia(
		visualPrompt: String,
		analyticsContext: AIAnalyticsContext? = nil
	) async throws -> SceneMediaResource {
		let trimmed = visualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { throw SceneMediaError.emptyPrompt }

		var properties: [String: Any] = [
			"prompt_length": trimmed.count,
		]
		if let sessionID = analyticsContext?.sessionID {
			properties["game_session_id"] = sessionID
		}
		if let turnID = analyticsContext?.turnID {
			properties["turn_id"] = turnID
		}
		AppAnalytics.capture("vision_scene_generate_started", properties: properties)

		do {
			let url = try await service.generateSceneImage(
				prompt: trimmed,
				analyticsContext: analyticsContext
			)
			properties["url_host"] = url.host ?? ""
			AppAnalytics.capture("vision_scene_generate_succeeded", properties: properties)
			return SceneMediaResource(url: url, kind: .image)
		} catch {
			properties["error_type"] = String(describing: type(of: error))
			properties["error_message"] = error.localizedDescription
			AppAnalytics.capture("vision_scene_generate_failed", properties: properties)
			throw error
		}
	}

	private func validateTurn(
		_ turn: AITurnResult<PromptOutput>,
		analyticsContext: AIAnalyticsContext?
	) -> AITurnResult<PromptOutput> {
		var output = turn.output
		var properties: [String: Any] = [:]

		if let sessionID = analyticsContext?.sessionID {
			properties["game_session_id"] = sessionID
		}
		if let turnID = analyticsContext?.turnID {
			properties["turn_id"] = turnID
		}

		let normalizedCount = DungeonMasterTurnValidation.normalizedOptions(from: output.options).count
		if normalizedCount < DungeonMasterTurnValidation.minimumOptionCount {
			properties["option_count_before"] = normalizedCount
			output.options = DungeonMasterTurnValidation.paddedOptions(from: output.options)
			properties["option_count_after"] = output.options.count
			AppAnalytics.capture("dm_turn_invalid_options", properties: properties)
		} else {
			output.options = DungeonMasterTurnValidation.paddedOptions(from: output.options)
		}

		if !DungeonMasterTurnValidation.hasRequestAction(in: turn.toolEffects) {
			AppAnalytics.capture("dm_turn_missing_decide_action", properties: properties)
		}

		return AITurnResult(output: output, toolEffects: turn.toolEffects)
	}
}

//
//  DungeonMasterTurnValidationTests.swift
//  magoSanduicheTests
//

import Foundation
import OpenAI
import Testing
@testable import magoSanduiche

struct DungeonMasterTurnValidationTests {
	@Test func normalizedOptionsTrimsAndFiltersEmpty() {
		let result = DungeonMasterTurnValidation.normalizedOptions(from: [
			"  Fight  ",
			"",
			"  Flee  ",
		])
		#expect(result == ["Fight", "Flee"])
	}

	@Test func paddedOptionsFillsToThree() {
		let result = DungeonMasterTurnValidation.paddedOptions(from: ["Charge the door"])
		#expect(result.count == 3)
		#expect(result.first == "Charge the door")
	}

	@Test func paddedOptionsCapsAtThree() {
		let result = DungeonMasterTurnValidation.paddedOptions(from: [
			"One",
			"Two",
			"Three",
			"Four",
		])
		#expect(result == ["One", "Two", "Three"])
	}

	@Test func hasRequestActionDetectsDecideActionEffect() {
		let effects: [GameToolEffect] = [.requestAction(.write)]
		#expect(DungeonMasterTurnValidation.hasRequestAction(in: effects))
		#expect(!DungeonMasterTurnValidation.hasRequestAction(in: [.changeHealth(-2)]))
	}
}

@MainActor
final class FakeDungeonMasterModelClient: DungeonMasterModelClient {
	var generateHandler:
		(
			String, [AnyModelTool], Model, AIAnalyticsContext?
		) async throws -> AITurnResult<PromptOutput> = { _, _, _, _ in
			AITurnResult(
				output: PromptOutput(narrative: "> Test", toolResults: "", options: []),
				toolEffects: []
			)
		}

	func generateDungeonTurn(
		_ scenario: String,
		tools: [AnyModelTool],
		model: Model,
		analyticsContext: AIAnalyticsContext?
	) async throws -> AITurnResult<PromptOutput> {
		try await generateHandler(scenario, tools, model, analyticsContext)
	}

	func clearHistory() {}
}

struct DungeonMasterServiceValidationTests {
	@Test @MainActor func validateTurnPadsMissingOptions() async throws {
		let fake = FakeDungeonMasterModelClient()
		fake.generateHandler = { _, _, _, _ in
			AITurnResult(
				output: PromptOutput(
					narrative: "> Only narrative",
					toolResults: "",
					options: []
				),
				toolEffects: [.requestAction(.write)]
			)
		}

		let service = DungeonMasterService(modelClient: fake)
		let turn = try await service.generate("hello")

		#expect(turn.output.options.count == 3)
		#expect(DungeonMasterTurnValidation.hasRequestAction(in: turn.toolEffects))
	}

	@Test @MainActor func validateTurnPreservesToolEffectsWithoutDecideAction() async throws {
		let fake = FakeDungeonMasterModelClient()
		fake.generateHandler = { _, _, _, _ in
			AITurnResult(
				output: PromptOutput(
					narrative: "> Story",
					toolResults: "rollDice: 12",
					options: ["A", "B", "C"]
				),
				toolEffects: [.changeHealth(-1)]
			)
		}

		let service = DungeonMasterService(modelClient: fake)
		let turn = try await service.generate("attack")

		#expect(turn.toolEffects.count == 1)
		if case .changeHealth(-1) = turn.toolEffects[0] {
		} else {
			Issue.record("Expected changeHealth effect")
		}
		#expect(!DungeonMasterTurnValidation.hasRequestAction(in: turn.toolEffects))
	}
}

struct OpenAIServiceStructuredTurnTests {
	@Test @MainActor func generate_debugStub_runsToolsBeforeStructuredJSON() async throws {
		let defaultsKey = OpenAIService.debugStubUserDefaultsKey
		let previous = UserDefaults.standard.bool(forKey: defaultsKey)
		UserDefaults.standard.set(true, forKey: defaultsKey)
		defer { UserDefaults.standard.set(previous, forKey: defaultsKey) }

		let service = OpenAIService(apiKey: "debug-stub", instructions: Prompts.systemPrompt)
		let result = try await service.generate(
			"turnKind: playerText\nplayerMessage: I do a backflip",
			returning: PromptOutput.self,
			tools: DungeonMasterService.modelTools
		)

		#expect(DungeonMasterTurnValidation.hasRequestAction(in: result.toolEffects))
		#expect(result.output.options.count == 3)
		#expect(!result.output.narrative.isEmpty)
		#expect(result.output.narrative.contains("DEBUG STUB") || result.output.narrative.hasPrefix(">"))
	}

	@Test @MainActor func generate_narrativeOnlyJSONStillDecodesWithOptionsFromStub() async throws {
		let defaultsKey = OpenAIService.debugStubUserDefaultsKey
		let previous = UserDefaults.standard.bool(forKey: defaultsKey)
		UserDefaults.standard.set(true, forKey: defaultsKey)
		defer { UserDefaults.standard.set(previous, forKey: defaultsKey) }

		let service = OpenAIService(apiKey: "debug-stub", instructions: "")
		let result = try await service.generate(
			"turnKind: playerText\nplayerMessage: look around",
			returning: PromptOutput.self,
			tools: DungeonMasterService.modelTools
		)

		#expect(!result.output.options.isEmpty)
		#expect(result.output.options.count >= 3)
	}
}

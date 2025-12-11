//
//  DungeonMasterService.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation
import FoundationModels
import OpenAISession

enum AIAvailabilityErrors: Error {
	case unavailable(String)
}

class DungeonMasterService {
	//	private var master: LanguageModelSession
	private let actionCallback: ((Int) -> Void)?
	private var master: OpenAISession<NoSchema>
	private var instructions: String

	init(actionCallback: ((Int) -> Void)? = nil) throws {
		let modelAvailability = SystemLanguageModel.default

		guard modelAvailability.availability == .available else {
			throw AIAvailabilityErrors.unavailable("Foundation models are unavailable in this device :[")
		}

		self.instructions = Prompts.systemPrompt
		self.actionCallback = actionCallback
		// TODO: FIX THIS
		let apiKey =
			"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"
		let model = OpenAISession(
			tools: RollDice(), DecideAction(onActionRequested: self.actionCallback ?? { _ in }),
			instructions: self.instructions,
			apiKey: apiKey,
		)

		self.master = model
	}

	// MARK: - generation
	public func generate(_ scenario: String) async throws -> PromptOutput {
		do {
			let response = try await master.respond(
				to: scenario,
				generating: DungeonMasterOutput.self,
				using: .gpt5_mini,
			)
			print(response.content)
			return response.content.output
		} catch {
			print(error.localizedDescription)
			throw error
		}
	}
}

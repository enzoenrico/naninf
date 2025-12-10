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
	private var master: OpenAISession<NoSchema>
	private var options: GenerationOptions
	private var instructions: String

	init() throws {
		let modelAvailability = SystemLanguageModel.default

		guard modelAvailability.availability == .available else {
			throw AIAvailabilityErrors.unavailable("Foundation models are unavailable in this device :[")
		}

		self.options = GenerationOptions(temperature: 0.9)

		self.instructions = Prompts.systemPrompt
		// self.instructions = Prompts.debug
		//		let model = SystemLanguageModel(useCase: .general)
		//        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
		//            throw AIAvailabilityErrors.unavailable("No api keys vro")
		//        }
		let apiKey =
			"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"
		let model = OpenAISession(
			tools: RollDice(),
			instructions: self.instructions,
			apiKey: apiKey,
		)

		//		self.master = LanguageModelSession(
		//			model: model,
		//			tools: [RollDice()],
		//			instructions: self.instructions
		//		)
		self.master = model
	}

	// MARK: - generation
	public func generate(_ scenario: String) async throws {
		do {
			// old way

			//			let response = try await master.respond(
			//				to: scenario,
			//				generating: PromptOutput.self,
			//				options: self.options
			//			)
			//            print(response.content.instructionsRepresentation)
			//            return response.content

			let response = try await master.respond(
				to: scenario,
				//                generating: DungeonMasterOutput.self,
				using: .gpt5_mini,
			)
			print(response.content)
			//            return response.content.output
		} catch {
			print(error.localizedDescription)
			throw error
		}
	}

	//    public func prewarm(with history: Prompt?) {
	//        if let history {
	//            master.prewarm(promptPrefix: history)
	//        } else {
	//            master.prewarm()
	//        }
	//    }

}

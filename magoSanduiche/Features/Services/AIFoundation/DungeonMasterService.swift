    //
    //  DungeonMasterService.swift
    //  magoSanduiche
    //
    //  Created by Enzo Enrico on 08/12/25.
    //

import Foundation
import FoundationModels

enum AIAvailabilityErrors: Error {
    case unavailable(String)
}

class DungeonMasterService {
    private var master: LanguageModelSession
    private var options: GenerationOptions
    private var instructions: String
    
    init() throws {
        let modelAvailability = SystemLanguageModel.default
        
        guard modelAvailability.availability == .available else {
            throw AIAvailabilityErrors.unavailable("Foundation models are unavailable in this device :[")
        }
        
        self.options = GenerationOptions( temperature: 1.2 )
        
        self.instructions = Prompts.systemPrompt
        
        self.master = LanguageModelSession(instructions: self.instructions)
    }
    
        // MARK: - generation
    public func generate(_ scenario: String) async throws -> PromptOutput {
        do  {
            let response = try await master.respond(
                to: scenario,
                generating: PromptOutput.self,
                options: self.options
            )
            return response.content
        } catch {
            throw error
        }
    }
    
    public func prewarm(with history: Prompt?) {
        if let history {
            master.prewarm(promptPrefix: history)
        } else {
            master.prewarm()
        }
    }
}

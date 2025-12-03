//
//  LocalAIModel.swift
//  naninf
//
//  Created by Enzo Enrico on 03/12/25.
//

import FoundationModels

class LocalDungeonMaster: AIModel {
    var session: LanguageModelSession
    var tools: [any Tool]
    
    private let startingPrompt: Prompt = Prompts.storyPrompt
    
    init(tools: [Tool]){
        self.tools = []
        session.prewarm(promptPrefix: startingPrompt)
    }
    
    // MARK: - Public functions
    func generate(_ prompt: Prompt) -> AIResponseModel {
        session.respond()
    }

    
}
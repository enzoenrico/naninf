//
//  AIModelProtocol.swift
//  naninf
//
//  Created by Enzo Enrico on 03/12/25.
//

import FoundationModels

protocol AIModel {
    var session: LanguageModelSession { get set }
    var tools: [any Tool] { get set }
    var startingPrompt: Prompt { get }
    func generate(_ prompt: Prompt) -> AIResponseModel
}

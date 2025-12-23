//
//  PromptOutput.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation
import OpenAI

struct PromptOutput: StructuredOutput, Sendable {
    /// Use this field to describe the story, progression and consequences of user's actions in this world.
    /// Use paragraphs starting with `>` to denote progression.
    /// Describe the environment and the immediate consequences of the previous turn.
    var narrative: String

    /// The tools called and their output. Insert the tool's name and its result.
    var toolResults: String

    /// Three distinct options representing different approaches and paths the mage can follow.
    /// These approaches can be aggressive, stealthy, intellectual, whatever fits the situation.
    var options: [String]

    // MARK: - StructuredOutput Conformance

    nonisolated static var schemaName: String { "dungeonMasterOutput" }

    nonisolated static var schemaDict: [String: Any] {
        let narrativeProp: [String: Any] = [
            "type": "string",
            "description": "Use this field to describe the story, progression and consequences of user's actions in this world. Use paragraphs starting with `>` to denote progression. Describe the environment and the immediate consequences of the previous turn."
        ]

        let toolResultsProp: [String: Any] = [
            "type": "string",
            "description": "The tools called and their output. Insert the tool's name and its result."
        ]

        let optionsProp: [String: Any] = [
            "type": "array",
            "description": "Three distinct options representing different approaches and paths the mage can follow, these approaches can be aggressive, stealthy, intellectual, whatever fits the situation",
            "items": ["type": "string"] as [String: Any]
        ]

        let properties: [String: Any] = [
            "narrative": narrativeProp,
            "toolResults": toolResultsProp,
            "options": optionsProp
        ]

        return [
            "type": "object",
            "properties": properties,
            "required": ["narrative", "toolResults", "options"] as [String],
            "additionalProperties": false
        ]
    }
}

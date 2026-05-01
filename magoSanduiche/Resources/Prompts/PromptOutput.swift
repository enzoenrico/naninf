//
//  PromptOutput.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 08/12/25.
//

import Foundation

struct PromptOutput: StructuredOutput, Sendable {
	var narrative: String
	var toolResults: String
	var options: [String]

	enum CodingKeys: String, CodingKey {
		case narrative, toolResults, options
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		narrative = try container.decode(String.self, forKey: .narrative)
		options = try container.decode([String].self, forKey: .options)
		toolResults = try Self.decodeToolResults(from: container)
	}

	init(narrative: String, toolResults: String, options: [String]) {
		self.narrative = narrative
		self.toolResults = toolResults
		self.options = options
	}

	nonisolated static var schemaName: String { "dungeonMasterOutput" }

	nonisolated static var schemaDict: [String: Any] {
		[
			"type": "object",
			"properties": [
				"narrative": [
					"type": "string",
					"description":
						"Use this field to describe the story, progression and consequences of user's actions in this world. Use paragraphs starting with `>` to denote progression. Describe the environment and the immediate consequences of the previous turn.",
				],
				"toolResults": [
					"type": "string",
					"description": "The tools called and their output. Insert the tool's name and its result.",
				],
				"options": [
					"type": "array",
					"description":
						"Three distinct options representing different approaches and paths the mage can follow.",
					"items": ["type": "string"],
				],
			],
			"required": ["narrative", "toolResults", "options"],
			"additionalProperties": false,
		]
	}

	private static func decodeToolResults(
		from container: KeyedDecodingContainer<CodingKeys>
	) throws -> String {
		if let value = try? container.decode(String.self, forKey: .toolResults) {
			return value
		}

		var arrayContainer = try container.nestedUnkeyedContainer(forKey: .toolResults)
		var results: [String] = []

		while !arrayContainer.isAtEnd {
			if let value = try? arrayContainer.decode(String.self) {
				results.append(value)
			} else if let value = try? arrayContainer.decode([String: String].self) {
				results.append(formatToolResult(value))
			} else {
				break
			}
		}

		return results.joined(separator: ". ")
	}

	private static func formatToolResult(_ value: [String: String]) -> String {
		guard let tool = value["tool"] else { return "" }
		guard let result = value["result"] else { return tool }
		return "\(tool): \(result)"
	}
}

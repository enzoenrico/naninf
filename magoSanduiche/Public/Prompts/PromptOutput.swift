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

	// Custom decoder to handle toolResults as either string or array
	enum CodingKeys: String, CodingKey {
		case narrative, toolResults, options
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		narrative = try container.decode(String.self, forKey: .narrative)
		options = try container.decode([String].self, forKey: .options)

		// Handle toolResults as either string or array of objects
		do {
			toolResults = try container.decode(String.self, forKey: .toolResults)
		} catch {
			// If string decoding fails, try as array and convert to string
			do {
				var arrayContainer = try container.nestedUnkeyedContainer(forKey: .toolResults)
				var results: [String] = []
				while !arrayContainer.isAtEnd {
					if let dict = try? arrayContainer.decode([String: String].self) {
						if let tool = dict["tool"], let result = dict["result"] {
							results.append("\(tool): \(result)")
						} else if let tool = dict["tool"] {
							results.append(tool)
						}
					} else if let str = try? arrayContainer.decode(String.self) {
						results.append(str)
					} else {
						// Skip unknown types
						break
					}
				}
				toolResults = results.isEmpty ? "" : results.joined(separator: ". ")
			} catch {
				// If both fail, rethrow the original string decoding error
				throw DecodingError.typeMismatch(
					String.self,
					DecodingError.Context(
						codingPath: container.codingPath + [CodingKeys.toolResults],
						debugDescription: "Expected String or Array, but found neither"
					)
				)
			}
		}
	}

	init(narrative: String, toolResults: String, options: [String]) {
		self.narrative = narrative
		self.toolResults = toolResults
		self.options = options
	}

	// MARK: - StructuredOutput Conformance

	nonisolated static var schemaName: String { "dungeonMasterOutput" }

	nonisolated static var schemaDict: [String: Any] {
		let narrativeProp: [String: Any] = [
			"type": "string",
			"description":
				"Use this field to describe the story, progression and consequences of user's actions in this world. Use paragraphs starting with `>` to denote progression. Describe the environment and the immediate consequences of the previous turn.",
		]

		let toolResultsProp: [String: Any] = [
			"type": "string",
			"description":
				"The tools called and their output. Insert the tool's name and its result.",
		]

		let optionsProp: [String: Any] = [
			"type": "array",
			"description":
				"Three distinct options representing different approaches and paths the mage can follow, these approaches can be aggressive, stealthy, intellectual, whatever fits the situation",
			"items": ["type": "string"] as [String: Any],
		]

		let properties: [String: Any] = [
			"narrative": narrativeProp,
			"toolResults": toolResultsProp,
			"options": optionsProp,
		]

		return [
			"type": "object",
			"properties": properties,
			"required": ["narrative", "toolResults", "options"] as [String],
			"additionalProperties": false,
		]
	}
}

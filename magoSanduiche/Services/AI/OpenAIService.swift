//
//  OpenAIService.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 23/12/24.
//

import Foundation
import Observation
import OpenAI

protocol ExecutableTool: Sendable {
	static var definition: ChatQuery.ChatCompletionToolParam { get }
	static var name: String { get }
	static func execute(arguments: String) async throws -> String
}

enum OpenAIServiceError: Error, LocalizedError {
	case noResponseContent
	case decodingFailed(String)
	case maxIterationsReached

	var errorDescription: String? {
		switch self {
		case .noResponseContent:
			"No content in OpenAI response"
		case .decodingFailed(let message):
			"Failed to decode response: \(message)"
		case .maxIterationsReached:
			"Maximum tool call iterations reached"
		}
	}
}

@Observable
@MainActor
final class OpenAIService {
	private let client: OpenAI
	private let instructions: String
	private let maxIterations = 20
	private var conversationHistory: [ChatQuery.ChatCompletionMessageParam] = []

	init(apiKey: String, instructions: String = "") {
		let config = OpenAI.Configuration(token: apiKey)
		self.client = OpenAI(configuration: config)
		self.instructions = instructions
		resetConversationHistory()
	}

	func clearHistory() {
		resetConversationHistory()
	}

	func generate<T: StructuredOutput>(
		_ prompt: String,
		returning type: T.Type,
		tools: [any ExecutableTool.Type] = [],
		model: Model = .gpt4_o
	) async throws -> T {
		let fullPrompt = "\(prompt)\n\n\(schemaInstruction(for: type))"
		conversationHistory.append(.init(role: .user, content: fullPrompt)!)

		let content = try await runAgentLoop(
			tools: tools,
			toolDefinitions: tools.map { $0.definition },
			responseFormat: .jsonObject,
			model: model
		)

		guard let jsonData = content.data(using: .utf8) else {
			throw OpenAIServiceError.decodingFailed("Failed to convert response to data")
		}

		do {
			return try JSONDecoder().decode(T.self, from: jsonData)
		} catch {
			throw OpenAIServiceError.decodingFailed(
				"\(error.localizedDescription)\nRaw content: \(content)"
			)
		}
	}

	func generate(
		_ prompt: String,
		tools: [any ExecutableTool.Type] = [],
		model: Model = .gpt4_o
	) async throws -> String {
		conversationHistory.append(.init(role: .user, content: prompt)!)

		return try await runAgentLoop(
			tools: tools,
			toolDefinitions: tools.map { $0.definition },
			responseFormat: nil,
			model: model
		)
	}

	private func resetConversationHistory() {
		conversationHistory = []
		guard !instructions.isEmpty else { return }
		conversationHistory.append(.init(role: .system, content: instructions)!)
	}

	private func schemaInstruction<T: StructuredOutput>(for type: T.Type) -> String {
		let fieldDescriptions = schemaFieldDescriptions(for: type)
		return """
			IMPORTANT: Your response must be a JSON object with these EXACT fields and types:
			\(fieldDescriptions.joined(separator: "\n"))

			CRITICAL: Match the types exactly - strings must be plain text strings, arrays must be arrays of strings.
			Return ONLY the JSON object with actual data values, NOT the schema definition.
			"""
	}

	private func schemaFieldDescriptions<T: StructuredOutput>(for type: T.Type) -> [String] {
		guard let properties = T.schemaDict["properties"] as? [String: Any] else { return [] }

		return properties.compactMap { key, value in
			guard let property = value as? [String: Any],
				let type = property["type"] as? String,
				let description = property["description"] as? String
			else {
				return nil
			}

			let typeDescription: String
			let example: String

			switch (key, type) {
			case (_, "array"):
				typeDescription = "array of strings"
				example = " Example: [\"option1\", \"option2\", \"option3\"]"
			case ("toolResults", "string"):
				typeDescription = "string (plain text, NOT an array or object)"
				example = " Example: \"rollDice: Rolled a d20: 15\" or \"decideAction: Action requested: text input\""
			case ("narrative", "string"):
				typeDescription = "string (plain text, NOT an array or object)"
				example = " Example: \"> You enter the dark corridor...\""
			case (_, "string"):
				typeDescription = "string (plain text, NOT an array or object)"
				example = ""
			default:
				typeDescription = type
				example = ""
			}

			return "- \"\(key)\": MUST be \(typeDescription).\(example) \(description)"
		}
	}

	private func runAgentLoop(
		tools: [any ExecutableTool.Type],
		toolDefinitions: [ChatQuery.ChatCompletionToolParam],
		responseFormat: ChatQuery.ResponseFormat?,
		model: Model
	) async throws -> String {
		for _ in 0..<maxIterations {
			let query = ChatQuery(
				messages: conversationHistory,
				model: model,
				responseFormat: responseFormat,
				tools: toolDefinitions.isEmpty ? nil : toolDefinitions
			)

			let result = try await client.chats(query: query)
			guard let message = result.choices.first?.message else {
				throw OpenAIServiceError.noResponseContent
			}

			if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
				conversationHistory.append(
					.init(
						role: .assistant,
						content: message.content,
						toolCalls: toolCalls.map { toolCall in
							.init(
								id: toolCall.id,
								function: .init(
									arguments: toolCall.function.arguments,
									name: toolCall.function.name
								)
							)
						}
					)!
				)

				for toolCall in toolCalls {
					let toolName = toolCall.function.name
					guard let tool = tools.first(where: { $0.name == toolName }) else {
						appendToolResult("Error: Tool '\(toolName)' not found", toolCallId: toolCall.id)
						continue
					}

					do {
						let result = try await tool.execute(arguments: toolCall.function.arguments)
						appendToolResult(result, toolCallId: toolCall.id)
					} catch {
						appendToolResult("Error executing tool: \(error.localizedDescription)", toolCallId: toolCall.id)
					}
				}

				continue
			}

			guard let content = message.content else {
				throw OpenAIServiceError.noResponseContent
			}

			conversationHistory.append(.init(role: .assistant, content: content)!)
			return content
		}

		throw OpenAIServiceError.maxIterationsReached
	}

	private func appendToolResult(_ content: String, toolCallId: String) {
		conversationHistory.append(
			.init(
				role: .tool,
				content: content,
				toolCallId: toolCallId
			)!
		)
	}
}

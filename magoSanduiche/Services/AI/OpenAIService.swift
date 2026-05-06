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
		model: Model = .gpt4_o,
		analyticsContext: AIAnalyticsContext? = nil
	) async throws -> T {
		let fullPrompt = "\(prompt)\n\n\(schemaInstruction(for: type))"
		conversationHistory.append(.init(role: .user, content: fullPrompt)!)

		let content = try await runAgentLoop(
			tools: tools,
			toolDefinitions: tools.map { $0.definition },
			responseFormat: .jsonObject,
			model: model,
			analyticsContext: analyticsContext
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
		model: Model = .gpt4_o,
		analyticsContext: AIAnalyticsContext? = nil
	) async throws -> String {
		conversationHistory.append(.init(role: .user, content: prompt)!)

		return try await runAgentLoop(
			tools: tools,
			toolDefinitions: tools.map { $0.definition },
			responseFormat: nil,
			model: model,
			analyticsContext: analyticsContext
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
		model: Model,
		analyticsContext: AIAnalyticsContext?
	) async throws -> String {
		let traceID = analyticsContext?.turnID ?? UUID().uuidString
		let sessionID = analyticsContext?.sessionID
		let turnStartedAt = Date()
		var accumulatedUsage = TokenUsageAccumulator()

		for iteration in 0..<maxIterations {
			let requestPayload = jsonObject(from: conversationHistory)
			let spanID = UUID().uuidString
			let requestStartedAt = Date()
			let query = ChatQuery(
				messages: conversationHistory,
				model: model,
				responseFormat: responseFormat,
				tools: toolDefinitions.isEmpty ? nil : toolDefinitions
			)

			let result: ChatResult
			do {
				result = try await client.chats(query: query)
			} catch {
				AppAnalytics.captureAIError(
					traceID: traceID,
					sessionID: sessionID,
					spanID: spanID,
					spanName: "chat_completion",
					model: model,
					input: requestPayload,
					latency: Date().timeIntervalSince(requestStartedAt),
					error: error,
					properties: analyticsProperties(
						sessionID: sessionID,
						traceID: traceID,
						spanID: spanID,
						iteration: iteration,
						responseFormat: responseFormat,
						extra: ["tool_definition_count": toolDefinitions.count]
					)
				)
				captureAITurnFailed(
					traceID: traceID,
					sessionID: sessionID,
					startedAt: turnStartedAt,
					accumulatedUsage: accumulatedUsage,
					error: error
				)
				throw error
			}

			accumulatedUsage.add(result.usage)
			guard let message = result.choices.first?.message else {
				let error = OpenAIServiceError.noResponseContent
				captureSuccessfulAIGeneration(
					result: result,
					input: requestPayload,
					traceID: traceID,
					sessionID: sessionID,
					spanID: spanID,
					iteration: iteration,
					responseFormat: responseFormat,
					latency: Date().timeIntervalSince(requestStartedAt)
				)
				captureAITurnFailed(
					traceID: traceID,
					sessionID: sessionID,
					startedAt: turnStartedAt,
					accumulatedUsage: accumulatedUsage,
					error: error
				)
				throw OpenAIServiceError.noResponseContent
			}

			captureSuccessfulAIGeneration(
				result: result,
				input: requestPayload,
				traceID: traceID,
				sessionID: sessionID,
				spanID: spanID,
				iteration: iteration,
				responseFormat: responseFormat,
				latency: Date().timeIntervalSince(requestStartedAt)
			)

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
						var properties = analyticsProperties(
							sessionID: sessionID,
							traceID: traceID,
							spanID: spanID,
							iteration: iteration,
							responseFormat: responseFormat,
							extra: [
								"tool_name": toolName,
								"tool_call_id": toolCall.id,
								"error_type": String(describing: type(of: error)),
								"error_message": error.localizedDescription
							]
						)
						properties["$ai_is_error"] = true
						AppAnalytics.capture("ai_tool_execution_failed", properties: properties)
						appendToolResult("Error executing tool: \(error.localizedDescription)", toolCallId: toolCall.id)
					}
				}

				continue
			}

			guard let content = message.content else {
				let error = OpenAIServiceError.noResponseContent
				captureAITurnFailed(
					traceID: traceID,
					sessionID: sessionID,
					startedAt: turnStartedAt,
					accumulatedUsage: accumulatedUsage,
					error: error
				)
				throw OpenAIServiceError.noResponseContent
			}

			conversationHistory.append(.init(role: .assistant, content: content)!)
			captureAITurnCompleted(
				traceID: traceID,
				sessionID: sessionID,
				startedAt: turnStartedAt,
				accumulatedUsage: accumulatedUsage,
				iterationCount: iteration + 1
			)
			return content
		}

		let error = OpenAIServiceError.maxIterationsReached
		captureAITurnFailed(
			traceID: traceID,
			sessionID: sessionID,
			startedAt: turnStartedAt,
			accumulatedUsage: accumulatedUsage,
			error: error
		)
		throw OpenAIServiceError.maxIterationsReached
	}

	private func captureSuccessfulAIGeneration(
		result: ChatResult,
		input: Any,
		traceID: String,
		sessionID: String?,
		spanID: String,
		iteration: Int,
		responseFormat: ChatQuery.ResponseFormat?,
		latency: TimeInterval
	) {
		let toolCallCount = result.choices.reduce(0) { count, choice in
			count + (choice.message.toolCalls?.count ?? 0)
		}
		var extra: [String: Any] = [
			"openai_response_id": result.id,
			"finish_reason": result.choices.first?.finishReason ?? "unknown",
			"tool_call_count": toolCallCount,
			"is_final_response": toolCallCount == 0,
			"choice_count": result.choices.count,
			"system_fingerprint": result.systemFingerprint ?? "unknown"
		]
		if let serviceTier = result.serviceTier {
			extra["service_tier"] = String(describing: serviceTier)
		}

		AppAnalytics.captureAIGeneration(
			traceID: traceID,
			sessionID: sessionID,
			spanID: spanID,
			spanName: "chat_completion",
			model: result.model,
			input: input,
			outputChoices: jsonObject(from: result.choices),
			inputTokens: result.usage?.promptTokens,
			outputTokens: result.usage?.completionTokens,
			totalTokens: result.usage?.totalTokens,
			latency: latency,
			properties: analyticsProperties(
				sessionID: sessionID,
				traceID: traceID,
				spanID: spanID,
				iteration: iteration,
				responseFormat: responseFormat,
				extra: extra
			)
		)
	}

	private func captureAITurnCompleted(
		traceID: String,
		sessionID: String?,
		startedAt: Date,
		accumulatedUsage: TokenUsageAccumulator,
		iterationCount: Int
	) {
		var properties = aiTurnProperties(
			traceID: traceID,
			sessionID: sessionID,
			startedAt: startedAt,
			accumulatedUsage: accumulatedUsage
		)
		properties["iteration_count"] = iterationCount
		AppAnalytics.capture("ai_turn_completed", properties: properties)
	}

	private func captureAITurnFailed(
		traceID: String,
		sessionID: String?,
		startedAt: Date,
		accumulatedUsage: TokenUsageAccumulator,
		error: Error
	) {
		var properties = aiTurnProperties(
			traceID: traceID,
			sessionID: sessionID,
			startedAt: startedAt,
			accumulatedUsage: accumulatedUsage
		)
		properties["error_type"] = String(describing: type(of: error))
		properties["error_message"] = error.localizedDescription
		properties["$ai_is_error"] = true
		AppAnalytics.capture("ai_turn_failed", properties: properties)
	}

	private func aiTurnProperties(
		traceID: String,
		sessionID: String?,
		startedAt: Date,
		accumulatedUsage: TokenUsageAccumulator
	) -> [String: Any] {
		var properties: [String: Any] = [
			"turn_id": traceID,
			"$ai_trace_id": traceID,
			"duration": Date().timeIntervalSince(startedAt),
			"input_tokens": accumulatedUsage.inputTokens,
			"output_tokens": accumulatedUsage.outputTokens,
			"total_tokens": accumulatedUsage.totalTokens
		]
		if let sessionID {
			properties["game_session_id"] = sessionID
			properties["$ai_session_id"] = sessionID
		}
		return properties
	}

	private func analyticsProperties(
		sessionID: String?,
		traceID: String,
		spanID: String,
		iteration: Int,
		responseFormat: ChatQuery.ResponseFormat?,
		extra: [String: Any] = [:]
	) -> [String: Any] {
		var properties: [String: Any] = [
			"turn_id": traceID,
			"$ai_trace_id": traceID,
			"span_id": spanID,
			"iteration": iteration + 1,
			"response_format": responseFormat == nil ? "text" : "json_object"
		]
		if let sessionID {
			properties["game_session_id"] = sessionID
			properties["$ai_session_id"] = sessionID
		}
		return properties.merging(extra) { _, new in new }
	}

	private func jsonObject<T: Encodable>(from value: T) -> Any {
		let encoder = JSONEncoder()
		guard
			let data = try? encoder.encode(value),
			let jsonObject = try? JSONSerialization.jsonObject(with: data)
		else {
			return String(describing: value)
		}
		return jsonObject
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

private struct TokenUsageAccumulator {
	private(set) var inputTokens = 0
	private(set) var outputTokens = 0
	private(set) var totalTokens = 0

	mutating func add(_ usage: ChatResult.CompletionUsage?) {
		guard let usage else { return }
		inputTokens += usage.promptTokens
		outputTokens += usage.completionTokens
		totalTokens += usage.totalTokens
	}
}

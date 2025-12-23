//
//  OpenAIService.swift
//  magoSanduiche
//
//  Created by Migration on 23/12/24.
//

import Foundation
import Observation
import OpenAI

// MARK: - Tool Protocol

/// Protocol for executable tools that can be called by the AI model.
protocol ExecutableTool: Sendable {
    /// The ChatTool definition for OpenAI API.
    static var definition: ChatQuery.ChatCompletionToolParam { get }

    /// The name of the tool (must match the function name in the definition).
    static var name: String { get }

    /// Execute the tool with the given JSON arguments and return a result string.
    static func execute(arguments: String) async throws -> String
}

// MARK: - OpenAI Service Errors

enum OpenAIServiceError: Error, LocalizedError {
    case noResponseContent
    case decodingFailed(String)
    case toolExecutionFailed(String, Error)
    case maxIterationsReached

    var errorDescription: String? {
        switch self {
        case .noResponseContent:
            return "No content in OpenAI response"
        case let .decodingFailed(message):
            return "Failed to decode response: \(message)"
        case let .toolExecutionFailed(toolName, error):
            return "Tool '\(toolName)' execution failed: \(error.localizedDescription)"
        case .maxIterationsReached:
            return "Maximum tool call iterations reached"
        }
    }
}

// MARK: - OpenAI Service

/// A generic service for interacting with OpenAI's API with support for
/// typed structured outputs and tool calling.
@Observable
@MainActor
class OpenAIService {
    private let client: OpenAI
    private let instructions: String
    private var conversationHistory: [ChatQuery.ChatCompletionMessageParam] = []

    /// Maximum number of tool call iterations before giving up.
    private let maxIterations: Int = 20

    init(apiKey: String, instructions: String = "") {
        let config = OpenAI.Configuration(token: apiKey)
        self.client = OpenAI(configuration: config)
        self.instructions = instructions

        if !instructions.isEmpty {
            conversationHistory.append(
                .init(role: .system, content: instructions)!
            )
        }
    }

    /// Clears the conversation history, keeping only the system instructions.
    func clearHistory() {
        conversationHistory = []
        if !instructions.isEmpty {
            conversationHistory.append(
                .init(role: .system, content: instructions)!
            )
        }
    }

    /// Generate a response with a typed struct output.
    ///
    /// - Parameters:
    ///   - prompt: The user's input prompt.
    ///   - type: The type of structured output to generate.
    ///   - tools: Array of executable tools available to the model.
    ///   - model: The OpenAI model to use.
    /// - Returns: A decoded instance of the specified output type.
    func generate<T: StructuredOutput>(
        _ prompt: String,
        returning type: T.Type,
        tools: [any ExecutableTool.Type] = [],
        model: Model = .gpt4_o
    ) async throws -> T {
        // Build the schema instruction to ensure JSON output
        let schemaJson = try JSONSerialization.data(withJSONObject: T.schemaDict, options: .prettyPrinted)
        let schemaString = String(data: schemaJson, encoding: .utf8) ?? "{}"

        let jsonInstruction = """
        IMPORTANT: Your final response MUST be valid JSON matching this exact schema:
        \(schemaString)
        
        Do not include any text before or after the JSON. Only output the JSON object.
        """

        // Add user message with JSON instruction to history
        let fullPrompt = "\(prompt)\n\n\(jsonInstruction)"
        conversationHistory.append(
            .init(role: .user, content: fullPrompt)!
        )

        // Build tool definitions
        let toolDefinitions = tools.map { $0.definition }

        // Use json_object response format to ensure JSON output
        let responseFormat = ChatQuery.ResponseFormat.jsonObject

        // Run the agent loop (handle tool calls)
        let content = try await runAgentLoop(
            tools: tools,
            toolDefinitions: toolDefinitions,
            responseFormat: responseFormat,
            model: model
        )

        // Decode the structured output
        guard let jsonData = content.data(using: .utf8) else {
            throw OpenAIServiceError.decodingFailed("Failed to convert response to data")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: jsonData)
        } catch {
            throw OpenAIServiceError.decodingFailed("\(error.localizedDescription)\nRaw content: \(content)")
        }
    }

    /// Generate a simple text response without structured output.
    ///
    /// - Parameters:
    ///   - prompt: The user's input prompt.
    ///   - tools: Array of executable tools available to the model.
    ///   - model: The OpenAI model to use.
    /// - Returns: The text response from the model.
    func generate(
        _ prompt: String,
        tools: [any ExecutableTool.Type] = [],
        model: Model = .gpt4_o
    ) async throws -> String {
        // Add user message to history
        conversationHistory.append(
            .init(role: .user, content: prompt)!
        )

        // Build tool definitions
        let toolDefinitions = tools.map { $0.definition }

        // Run the agent loop
        return try await runAgentLoop(
            tools: tools,
            toolDefinitions: toolDefinitions,
            responseFormat: nil,
            model: model
        )
    }

    // MARK: - Private Methods

    private func runAgentLoop(
        tools: [any ExecutableTool.Type],
        toolDefinitions: [ChatQuery.ChatCompletionToolParam],
        responseFormat: ChatQuery.ResponseFormat?,
        model: Model
    ) async throws -> String {
        var iterations = 0

        while iterations < maxIterations {
            iterations += 1

            // Create the query with optional response format
            let query = ChatQuery(
                messages: conversationHistory,
                model: model,
                responseFormat: responseFormat,
                tools: toolDefinitions.isEmpty ? nil : toolDefinitions
            )

            // Make the API call
            let result = try await client.chats(query: query)

            guard let choice = result.choices.first else {
                throw OpenAIServiceError.noResponseContent
            }

            let message = choice.message

            // Check if there are tool calls to handle
            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                // Add assistant message with tool calls to history
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

                // Execute each tool call and add results to history
                for toolCall in toolCalls {
                    let toolName = toolCall.function.name
                    let arguments = toolCall.function.arguments

                    // Find the matching tool
                    guard let tool = tools.first(where: { $0.name == toolName }) else {
                        // Tool not found, report error
                        conversationHistory.append(
                            .init(
                                role: .tool,
                                content: "Error: Tool '\(toolName)' not found",
                                toolCallId: toolCall.id
                            )!
                        )
                        continue
                    }

                    // Execute the tool
                    do {
                        let result = try await tool.execute(arguments: arguments)
                        conversationHistory.append(
                            .init(
                                role: .tool,
                                content: result,
                                toolCallId: toolCall.id
                            )!
                        )
                    } catch {
                        conversationHistory.append(
                            .init(
                                role: .tool,
                                content: "Error executing tool: \(error.localizedDescription)",
                                toolCallId: toolCall.id
                            )!
                        )
                    }
                }

                // Continue the loop to get next response
                continue
            }

            // No tool calls - this is the final response
            guard let content = message.content else {
                throw OpenAIServiceError.noResponseContent
            }

            // Add assistant response to history
            conversationHistory.append(
                .init(role: .assistant, content: content)!
            )

            return content
        }

        throw OpenAIServiceError.maxIterationsReached
    }
}

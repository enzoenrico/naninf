//
//  ModelTool.swift
//  magoSanduiche
//
//  Created by Cursor on 14/05/26.
//

import Foundation

protocol ModelTool: Sendable {
	associatedtype Arguments: Codable & Sendable
	associatedtype Result: ModelToolResult

	static var name: String { get }
	static var description: String { get }
	static var parameters: ToolParameterSchema { get }

	static func call(arguments: Arguments) async throws -> Result
}

protocol ModelToolResult: Sendable {
	var modelMessage: String { get }
	var effects: [GameToolEffect] { get }
}

extension ModelToolResult {
	var effects: [GameToolEffect] { [] }
}

struct AnyModelToolResult: ModelToolResult {
	let modelMessage: String
	let effects: [GameToolEffect]
}

struct AnyModelTool: Sendable {
	let name: String
	let description: String
	let parameters: ToolParameterSchema

	private let callWithJSON: @Sendable (String) async throws -> AnyModelToolResult

	init<T: ModelTool>(_ tool: T.Type) {
		self.name = tool.name
		self.description = tool.description
		self.parameters = tool.parameters
		self.callWithJSON = { jsonArguments in
			guard let data = jsonArguments.data(using: .utf8) else {
				throw ModelToolError.invalidArguments("Arguments are not valid UTF-8.")
			}

			do {
				let arguments = try JSONDecoder().decode(T.Arguments.self, from: data)
				let result = try await tool.call(arguments: arguments)
				return AnyModelToolResult(modelMessage: result.modelMessage, effects: result.effects)
			} catch let error as DecodingError {
				throw ModelToolError.invalidArguments(error.localizedDescription)
			}
		}
	}

	func call(jsonArguments: String) async throws -> AnyModelToolResult {
		try await callWithJSON(jsonArguments)
	}
}

enum ModelToolError: Error, LocalizedError {
	case invalidArguments(String)

	var errorDescription: String? {
		switch self {
		case .invalidArguments(let message):
			"Invalid tool arguments: \(message)"
		}
	}
}

struct ToolParameterSchema: Sendable {
	let integerFields: [ToolIntegerParameter]

	init(integerFields: [ToolIntegerParameter]) {
		self.integerFields = integerFields
	}

	var requiredPropertyNames: [String] {
		integerFields.filter(\.isRequired).map(\.name)
	}

	func defaultArgumentValues() -> [String: Int] {
		Dictionary(uniqueKeysWithValues: integerFields.map { ($0.name, $0.defaultValue) })
	}

	func jsonString(argumentValues: [String: Int]) -> String {
		let normalized = Dictionary(uniqueKeysWithValues: integerFields.map { field in
			(field.name, field.clamped(argumentValues[field.name] ?? field.defaultValue))
		})
		let data = try? JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys])
		return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
	}
}

struct ToolIntegerParameter: Identifiable, Sendable {
	let name: String
	let description: String
	let minimum: Int?
	let maximum: Int?
	let defaultValue: Int
	let isRequired: Bool

	var id: String { name }

	init(
		name: String,
		description: String,
		minimum: Int? = nil,
		maximum: Int? = nil,
		defaultValue: Int,
		isRequired: Bool = true
	) {
		self.name = name
		self.description = description
		self.minimum = minimum
		self.maximum = maximum
		self.defaultValue = defaultValue
		self.isRequired = isRequired
	}

	var closedRange: ClosedRange<Int> {
		(minimum ?? Int.min)...(maximum ?? Int.max)
	}

	func clamped(_ value: Int) -> Int {
		min(maximum ?? value, max(minimum ?? value, value))
	}
}

enum GameToolEffect: Sendable, CustomStringConvertible {
	case requestAction(GameAction)
	case changeHealth(Int)
	case changeMana(Int)

	var description: String {
		switch self {
		case .requestAction(.write):
			"requestAction(write)"
		case .requestAction(.roll):
			"requestAction(roll)"
		case .changeHealth(let amount):
			"changeHealth(\(amount))"
		case .changeMana(let amount):
			"changeMana(\(amount))"
		}
	}
}

struct AITurnResult<Output> {
	let output: Output
	let toolEffects: [GameToolEffect]
}

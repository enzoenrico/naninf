//
//  DecideAction.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 11/12/25.
//

import Foundation
import OpenAI

struct DecideActionTool: ExecutableTool {
	static let name = "decideAction"
	nonisolated(unsafe) static var onActionRequested: ((Int) -> Void)?

	static let definition = ChatQuery.ChatCompletionToolParam(
		function: .init(
			name: name,
			description:
				"Choose the next player input type. Use 0 for text input and 1 for dice roll."
		)
	)

	struct Arguments: Codable {
		let action: Int
	}

	static func execute(arguments: String) async throws -> String {
		guard let data = arguments.data(using: .utf8) else {
			return "Error: Invalid arguments"
		}

		let args = try JSONDecoder().decode(Arguments.self, from: data)
		let actionType = args.action == 0 ? "text input" : "dice roll"

		await MainActor.run {
			onActionRequested?(args.action)
		}

		return "Action requested: \(actionType). UI updated to show \(actionType) interface."
	}
}

//
//  ChangeHealth.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 11/12/25.
//

import Foundation
import OpenAI

struct ChangeHealthTool: ExecutableTool {
	static let name = "changeHealth"
	nonisolated(unsafe) static var onHealthChange: ((Int) -> Void)?

	static let definition = ChatQuery.ChatCompletionToolParam(
		function: .init(
			name: name,
			description:
				"Changes the player's health value. Use positive amounts to heal and negative amounts for damage. Range: -40 to 40."
		)
	)

	struct Arguments: Codable {
		let amount: Int
	}

	static func execute(arguments: String) async throws -> String {
		guard let data = arguments.data(using: .utf8) else {
			return "Error: Invalid arguments"
		}

		let args = try JSONDecoder().decode(Arguments.self, from: data)
		let amount = min(max(args.amount, -40), 40)

		await MainActor.run {
			onHealthChange?(amount)
		}

		switch amount {
		case let value where value > 0:
			return "Health increased by \(value)"
		case let value where value < 0:
			return "Health decreased by \(abs(value))"
		default:
			return "Health unchanged"
		}
	}
}

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

    /// Callback to notify when health should be changed.
    /// This needs to be set before the tool is used.
    nonisolated(unsafe) static var onHealthChange: ((Int) -> Void)?

    static let definition = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: name,
            description: "Changes the player's health value. Use positive amount to gain health, negative to lose health. Range: -40 to 40."
        )
    )

    struct Arguments: Codable {
        let amount: Int
    }

    static func execute(arguments: String) async throws -> String {
        let decoder = JSONDecoder()
        guard let data = arguments.data(using: .utf8) else {
            return "Error: Invalid arguments"
        }

        let args = try decoder.decode(Arguments.self, from: data)
        let clampedAmount = min(max(args.amount, -40), 40)

        // Notify via callback on main actor
        await MainActor.run {
            onHealthChange?(clampedAmount)
        }

        if clampedAmount > 0 {
            return "Health increased by \(clampedAmount)"
        } else if clampedAmount < 0 {
            return "Health decreased by \(abs(clampedAmount))"
        } else {
            return "Health unchanged"
        }
    }
}

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

    /// Callback to notify when an action is requested.
    /// This needs to be set before the tool is used.
    nonisolated(unsafe) static var onActionRequested: ((Int) -> Void)?

    static let definition = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: name,
            description: "When a player input is needed, if this input is a dice roll or a action input as text, you must decide and call this tool to make the action screen pop up to the player. Use 0 for text input and 1 for dice roll."
        )
    )

    struct Arguments: Codable {
        let action: Int
    }

    static func execute(arguments: String) async throws -> String {
        let decoder = JSONDecoder()
        guard let data = arguments.data(using: .utf8) else {
            return "Error: Invalid arguments"
        }

        let args = try decoder.decode(Arguments.self, from: data)

        // Notify via callback on main actor
        await MainActor.run {
            onActionRequested?(args.action)
        }

        let actionType = args.action == 0 ? "text input" : "dice roll"
        return "Action requested: \(actionType)"
    }
}

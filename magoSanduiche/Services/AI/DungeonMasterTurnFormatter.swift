//
//  DungeonMasterTurnFormatter.swift
//  magoSanduiche
//

import Foundation

enum DungeonMasterTurnKind: String, Sendable {
    case playerText
    case diceResultConfirmation
}

struct DungeonMasterTurnContext: Sendable {
    let kind: DungeonMasterTurnKind
    let playerMessage: String
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    let storySoFar: [TerminalEntry]
    let diceRoll: Int?

    func keepingRecentStory() -> DungeonMasterTurnContext {
        let relevant = storySoFar.filter { $0.kind == .player || $0.kind == .dungeonMaster }
        let recent = Array(relevant.suffix(2))
        guard recent.count < relevant.count else { return self }
        return DungeonMasterTurnContext(
            kind: kind,
            playerMessage: playerMessage,
            health: health,
            maxHealth: maxHealth,
            mana: mana,
            maxMana: maxMana,
            storySoFar: recent,
            diceRoll: diceRoll
        )
    }
}

enum DungeonMasterTurnFormatter {
    static let storyCharacterBudget = 8000

    static func format(_ context: DungeonMasterTurnContext) -> String {
        var lines: [String] = [
            "game: fictional tabletop fantasy",
            "turnKind: \(context.kind.rawValue)",
            "health: \(context.health)/\(context.maxHealth)",
            "mana: \(context.mana)/\(context.maxMana)",
        ]

        let story = storyLines(from: context.storySoFar, budget: storyCharacterBudget)
        if !story.isEmpty {
            lines.append("story:")
            lines.append(contentsOf: story)
        }

        switch context.kind {
        case .playerText:
            lines.append("playerMessage: \(context.playerMessage)")
        case .diceResultConfirmation:
            if let roll = context.diceRoll {
                lines.append("playerD20Roll: \(roll)")
            }
            if let pending = pendingCheckLine(from: context.storySoFar) {
                lines.append("pendingCheck: \(pending)")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func pendingCheckLine(from entries: [TerminalEntry]) -> String? {
        guard let text = entries.last(where: { $0.kind == .dungeonMaster })?.text else {
            return nil
        }
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        let limit = 500
        if collapsed.count <= limit {
            return collapsed
        }
        return String(collapsed.suffix(limit))
    }

    static func storyLines(from entries: [TerminalEntry], budget: Int) -> [String] {
        var chosenReversed: [String] = []
        var used = 0

        for entry in entries.reversed() {
            guard entry.kind == .player || entry.kind == .dungeonMaster else { continue }
            let speaker = entry.kind == .player ? "Mage" : "DM"
            var line = "\(speaker): \(entry.text)"
            if line.count > budget {
                line = String(line.suffix(budget))
            }

            let separator = chosenReversed.isEmpty ? 0 : 1
            if used + separator + line.count > budget {
                if chosenReversed.isEmpty {
                    chosenReversed.append(line)
                }
                break
            }

            chosenReversed.append(line)
            used += separator + line.count
        }

        return Array(chosenReversed.reversed())
    }
}

//
//  GameViewModel+Terminal.swift
//  magoSanduiche
//

import Foundation

extension GameViewModel {
    func markNarrativeFinished() {
        revealDeferredDicePromptIfNeeded()
        guard !loading else { return }
        switch uiPhase {
        case .reading, .result:
            uiPhase = .ready
        case .ready, .composing, .awaitingDungeonMaster, .rollingDice:
            break
        }
    }

    func isTerminalEntryRevealed(_ entryID: UUID) -> Bool {
        revealedTerminalEntryIDs.contains(entryID)
    }

    func updateTypewriterProgress(entryID: UUID, revealedCount: Int) {
        typewriterProgressByEntryID[entryID] = revealedCount
    }

    func markTerminalEntryRevealed(_ entryID: UUID) {
        revealedTerminalEntryIDs.insert(entryID)
        typewriterProgressByEntryID.removeValue(forKey: entryID)
    }

    func registerEmptyInput() {
        invalidInputAttempts += 1
        uiPhase = .composing
        capture("player_empty_input_submitted", extra: ["invalid_input_attempts": invalidInputAttempts])
    }

    func pruneTypewriterProgress() {
        guard let latestID = terminalEntries.last?.id else {
            typewriterProgressByEntryID.removeAll()
            return
        }
        typewriterProgressByEntryID = typewriterProgressByEntryID.filter { $0.key == latestID }
    }
}

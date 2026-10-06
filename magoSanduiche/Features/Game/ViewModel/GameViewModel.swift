//
//  GameViewModel.swift
//  magoSanduiche
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class GameViewModel {
    weak var coordinator: AppCoordinator?
    let dungeonMaster: DungeonMasterService

    var gameSessionID: String
    var modelContext: ModelContext?
    let persistRunsToLibrary: Bool
    var persistedRunID: UUID?

    var suppressTerminalAnimations = false
    var shouldShowDicePromptAfterNarrative = false

    var loading = false
    var visionDisplayMode: VisionDisplayMode = .introStatic
    var visionMediaLoading = false
    var hasSubmittedPlayerTurn = false
    var contextAction: GameAction = .write
    var uiPhase: GameUIPhase = .reading
    var health = 50
    var mana = 20
    var maxHealth = 50
    var maxMana = 30
    var diceValue = 20
    var diceRevealStage = DiceRevealStage.idle
    var pendingDiceRoll: Int?
    var diceResultText = String(localized: "nan_dice_idle_cold")
    var invalidInputAttempts = 0
    var contextualInput = ""
    var suggestedOptions: [String] = []
    var selectedSuggestionIndex: Int?
    var onCompletedPlayerAction: (() -> Void)?
    var terminalEntries: [TerminalEntry] = GameRunSnapshotMapper.defaultTerminalEntries
    var revealedTerminalEntryIDs: Set<UUID> = []
    var typewriterProgressByEntryID: [UUID: Int] = [:]

    var canOpenVisionTerminal: Bool {
        if !hasSubmittedPlayerTurn { return true }
        if visionMediaLoading { return false }
        if case .scene = visionDisplayMode { return true }
        return false
    }

    init(
        coordinator: AppCoordinator? = nil,
        persistRunsToLibrary: Bool = true,
        dungeonMaster: DungeonMasterService? = nil
    ) {
        self.coordinator = coordinator
        gameSessionID = UUID().uuidString
        self.persistRunsToLibrary = persistRunsToLibrary
        // Default arguments are nonisolated, so the narrator is created in this MainActor body.
        self.dungeonMaster = dungeonMaster ?? DungeonMasterService()
        capture(
            "game_session_started",
            extra: [
                "persist_runs": persistRunsToLibrary,
            ]
        )
    }

    func attachCoordinator(_ coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    #if DEBUG
        var uiTestShowsSuggestions = false

        /// Loads a deterministic fixture so UI tests can screenshot a specific game state.
        func applyUITestState(_ fixture: UITestGameFixture) {
            suppressTerminalAnimations = true
            uiTestShowsSuggestions = fixture.showsSuggestions
            let entries = fixture.terminalEntries.isEmpty
                ? GameRunSnapshotMapper.defaultTerminalEntries
                : fixture.terminalEntries
            terminalEntries = entries
            revealedTerminalEntryIDs = Set(entries.map(\.id))
            suggestedOptions = fixture.suggestedOptions
            selectedSuggestionIndex = nil
            health = fixture.health
            mana = fixture.mana
            maxHealth = fixture.maxHealth
            maxMana = fixture.maxMana
            uiPhase = fixture.phase
            contextAction = fixture.contextAction
            diceValue = fixture.diceValue
            diceRevealStage = fixture.diceRevealStage
            pendingDiceRoll = fixture.pendingDiceRoll
            diceResultText = fixture.diceResultText
            contextualInput = fixture.contextualInput
            invalidInputAttempts = fixture.invalidInputAttempts
            loading = fixture.loading
            hasSubmittedPlayerTurn = true
            visionDisplayMode = .introStatic
        }
    #endif
}

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
    var dungeonMaster: DungeonMasterService?

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
        if case .remote = visionDisplayMode { return true }
        return false
    }

    init(coordinator: AppCoordinator? = nil, persistRunsToLibrary: Bool = true) {
        self.coordinator = coordinator
        gameSessionID = UUID().uuidString
        self.persistRunsToLibrary = persistRunsToLibrary
        dungeonMaster = Self.makeDungeonMaster()
        capture(
            "game_session_started",
            extra: [
                "has_dungeon_master": dungeonMaster != nil,
                "persist_runs": persistRunsToLibrary,
            ]
        )
    }

    func attachCoordinator(_ coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    static func makeDungeonMaster() -> DungeonMasterService? {
        try? DungeonMasterService()
    }
}

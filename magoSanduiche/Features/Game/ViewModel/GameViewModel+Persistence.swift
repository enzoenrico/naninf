//
//  GameViewModel+Persistence.swift
//  magoSanduiche
//

import Foundation
import SwiftData

extension GameViewModel {
    func restore(runID: UUID, modelContext: ModelContext) {
        guard let stored = GameRunSnapshotMapper.fetch(id: runID, context: modelContext) else { return }

        self.modelContext = modelContext
        persistedRunID = stored.id
        gameSessionID = stored.analyticsSessionID
        applyPlaybackState(GameRunSnapshotMapper.playbackState(from: stored))
        visionDisplayMode = .introStatic
        visionMediaLoading = false
        visionGenerationProgress = nil
        latestVisionRequestID = nil
    }

    func saveSnapshot(modelContext: ModelContext) {
        self.modelContext = modelContext
        persistRun()
    }

    func persistRun() {
        guard persistRunsToLibrary, let modelContext else { return }

        do {
            let now = Date()
            let id = persistedRunID ?? UUID()
            let existing = GameRunSnapshotMapper.fetch(id: id, context: modelContext)
            let createdAt = existing?.createdAt ?? now
            let fields = try GameRunSnapshotMapper.snapshotFields(
                from: liveSnapshotState,
                createdAt: createdAt
            )

            if let existing {
                GameRunSnapshotMapper.apply(fields, to: existing, updatedAt: now, analyticsSessionID: gameSessionID)
            } else {
                let inserted = GameRunSnapshotMapper.makeStoredGameRun(
                    id: id,
                    createdAt: createdAt,
                    updatedAt: now,
                    fields: fields,
                    analyticsSessionID: gameSessionID
                )
                modelContext.insert(inserted)
            }
            try modelContext.save()
            persistedRunID = id
        } catch {
            #if DEBUG
                print("GameViewModel persist failed: \(error)")
            #endif
        }
    }

    private var liveSnapshotState: GameRunSnapshotMapper.LiveState {
        GameRunSnapshotMapper.LiveState(
            terminalEntries: terminalEntries,
            suggestedOptions: suggestedOptions,
            health: health,
            mana: mana,
            maxHealth: maxHealth,
            maxMana: maxMana,
            diceValue: diceValue,
            pendingDiceRoll: pendingDiceRoll,
            diceRevealStage: diceRevealStage,
            diceResultText: diceResultText,
            invalidInputAttempts: invalidInputAttempts,
            contextualInput: contextualInput,
            contextAction: contextAction,
            uiPhase: uiPhase,
            suppressTerminalAnimations: suppressTerminalAnimations
        )
    }

    private func applyPlaybackState(_ state: GameRunSnapshotMapper.PlaybackState) {
        terminalEntries = state.terminalEntries
        health = state.health
        mana = state.mana
        maxHealth = state.maxHealth
        maxMana = state.maxMana
        diceValue = state.diceValue
        pendingDiceRoll = state.pendingDiceRoll
        diceRevealStage = state.diceRevealStage
        diceResultText = state.diceResultText
        invalidInputAttempts = state.invalidInputAttempts
        contextualInput = state.contextualInput
        contextAction = state.contextAction
        uiPhase = state.uiPhase
        suggestedOptions = state.suggestedOptions
        suppressTerminalAnimations = state.suppressTerminalAnimations
        hasSubmittedPlayerTurn = state.terminalEntries.contains { $0.kind == .player }
    }
}

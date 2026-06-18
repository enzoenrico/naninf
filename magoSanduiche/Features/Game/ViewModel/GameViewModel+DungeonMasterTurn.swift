//
//  GameViewModel+DungeonMasterTurn.swift
//  magoSanduiche
//

import Foundation

#if canImport(UIKit)
    import UIKit
#endif

extension GameViewModel {
    func getResponse(for prompt: String) -> Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            registerEmptyInput()
            return false
        }
        guard !loading else { return false }

        let context = dungeonMasterTurnContext(
            kind: .playerText,
            playerMessage: trimmed,
            diceRoll: nil,
            diceOutcomeSummary: nil
        )
        beginDungeonMasterTurn(
            displayText: trimmed,
            context: context,
            analyticsEvent: "player_turn_submitted",
            extraAnalytics: ["prompt_length": trimmed.count]
        )
        return true
    }

    func beginDungeonMasterTurn(
        displayText: String,
        context: DungeonMasterTurnContext,
        analyticsEvent: String,
        extraAnalytics: [String: Any] = [:]
    ) {
        hasSubmittedPlayerTurn = true
        suppressTerminalAnimations = false
        suggestedOptions = []
        selectedSuggestionIndex = nil
        loading = true
        uiPhase = .awaitingDungeonMaster
        terminalEntries.append(TerminalEntry(kind: .player, text: displayText))
        contextualInput = ""

        let turnID = UUID().uuidString
        let startedAt = Date()
        var extra = extraAnalytics
        extra["turn_id"] = turnID
        extra["turn_kind"] = context.kind.rawValue
        extra["terminal_entry_count"] = terminalEntries.count
        capture(analyticsEvent, extra: extra)

        let narrativeTask = Task.detached(priority: .userInitiated) { @MainActor [self] in
            #if canImport(UIKit)
                var backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "dm_narrative") {}
                defer {
                    if backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = .invalid
                    }
                }
            #endif
            await fetchNarrative(context: context, turnID: turnID, startedAt: startedAt)
        }
        coordinator?.replacePendingNarrativeFetch(narrativeTask)
    }

    private func fetchNarrative(context: DungeonMasterTurnContext, turnID: String, startedAt: Date) async {
        defer {
            coordinator?.clearPendingNarrativeFetch()
            loading = false
            persistRun()
            onCompletedPlayerAction?()
        }

        do {
            guard
                let turn = try await dungeonMaster?.generate(
                    context: context,
                    analyticsContext: aiContext(turnID: turnID)
                )
            else {
                appendSystemMessage(String(localized: "nan_dm_silent"))
                capture(
                    "dm_turn_empty_response",
                    extra: [
                        "turn_id": turnID,
                        "duration": Date().timeIntervalSince(startedAt),
                    ]
                )
                return
            }

            let result = turn.output
            terminalEntries.append(TerminalEntry(kind: .dungeonMaster, text: result.narrative))
            pruneTypewriterProgress()
            suppressTerminalAnimations = false
            uiPhase = .result
            applyToolEffects(turn.toolEffects)
            suggestedOptions = result.options
            selectedSuggestionIndex = nil
            capture(
                "dm_turn_succeeded",
                extra: [
                    "turn_id": turnID,
                    "turn_kind": context.kind.rawValue,
                    "duration": Date().timeIntervalSince(startedAt),
                    "narrative_length": result.narrative.count,
                    "suggested_option_count": suggestedOptions.count,
                    "terminal_entry_count": terminalEntries.count,
                ]
            )
            Task {
                await handleVisionAfterTurn(visualPrompt: result.visualPrompt, turnID: turnID)
            }
        } catch {
            capture(
                "dm_turn_failed",
                extra: [
                    "turn_id": turnID,
                    "turn_kind": context.kind.rawValue,
                    "duration": Date().timeIntervalSince(startedAt),
                    "error_type": String(describing: type(of: error)),
                    "error_message": error.localizedDescription,
                ]
            )
            appendSystemMessage(String(localized: "nan_dm_error"))
        }
    }

    func dungeonMasterTurnContext(
        kind: DungeonMasterTurnKind,
        playerMessage: String,
        diceRoll: Int?,
        diceOutcomeSummary: String?
    ) -> DungeonMasterTurnContext {
        DungeonMasterTurnContext(
            kind: kind,
            playerMessage: playerMessage,
            health: health,
            maxHealth: maxHealth,
            mana: mana,
            maxMana: maxMana,
            latestDungeonMasterExcerpt: latestDungeonMasterExcerpt(),
            diceRoll: diceRoll,
            diceOutcomeSummary: diceOutcomeSummary
        )
    }

    private func latestDungeonMasterExcerpt() -> String? {
        for entry in terminalEntries.reversed() where entry.kind == .dungeonMaster {
            let trimmed = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func appendSystemMessage(_ text: String) {
        terminalEntries.append(TerminalEntry(kind: .system, text: text))
        pruneTypewriterProgress()
        uiPhase = .result
    }

    func applyToolEffects(_ effects: [GameToolEffect]) {
        for effect in effects {
            switch effect {
            case let .requestAction(action):
                applyRequestedAction(action)
            case let .changeHealth(amount):
                let healthBefore = health
                health = min(maxHealth, max(0, health + amount))
                capture(
                    "dm_health_changed",
                    extra: [
                        "amount": amount,
                        "health_before": healthBefore,
                        "health_after": health,
                        "health_delta": health - healthBefore,
                    ]
                )
            }
        }
    }

    func revealDeferredDicePromptIfNeeded() {
        guard shouldShowDicePromptAfterNarrative else { return }
        shouldShowDicePromptAfterNarrative = false
        coordinator?.showDicePrompt()
    }

    private func applyRequestedAction(_ action: GameAction) {
        switch action {
        case .write:
            shouldShowDicePromptAfterNarrative = false
            contextAction = .write
            uiPhase = .composing
            coordinator?.prepareForTextInput()
            capture("dm_action_requested", extra: ["action": "write"])
        case .roll:
            contextAction = .roll
            uiPhase = .rollingDice
            diceRevealStage = .idle
            pendingDiceRoll = nil
            if suppressTerminalAnimations {
                coordinator?.showDicePrompt()
            } else {
                shouldShowDicePromptAfterNarrative = true
            }
            capture("dm_action_requested", extra: ["action": "roll"])
        }
    }
}

#if DEBUG
    extension GameViewModel {
        func applyToolEffectsFromDebug(_ effects: [GameToolEffect]) {
            applyToolEffects(effects)
        }
    }
#endif

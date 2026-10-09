//
//  GameViewModel+DungeonMasterTurn.swift
//  magoSanduiche
//

import Foundation

#if canImport(UIKit)
    import UIKit
#endif

extension GameViewModel {
    func getResponse(for prompt: String, inputSource: String = "typed", suggestionIndex: Int? = nil) -> Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            registerEmptyInput()
            return false
        }
        guard !loading else { return false }

        let context = dungeonMasterTurnContext(
            kind: .playerText,
            playerMessage: trimmed,
            diceRoll: nil
        )
        var extraAnalytics: [String: Any] = [
            "prompt_length": trimmed.count,
            "input_source": inputSource,
        ]
        if let suggestionIndex {
            extraAnalytics["suggestion_index"] = suggestionIndex
        }
        beginDungeonMasterTurn(
            displayText: trimmed,
            context: context,
            analyticsEvent: "player_turn_submitted",
            extraAnalytics: extraAnalytics
        )
        return true
    }

    func appendPlayerLine(_ text: String) -> PlayerPromptID {
        let entry = TerminalEntry(kind: .player, text: text)
        terminalEntries.append(entry)
        return PlayerPromptID(entry)!
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
        let prompt = appendPlayerLine(displayText)
        contextualInput = ""

        let turnID = UUID().uuidString
        let startedAt = Date()
        var extra = extraAnalytics
        extra["turn_id"] = turnID
        extra["turn_kind"] = context.kind.rawValue
        extra["terminal_entry_count"] = terminalEntries.count
        capture(analyticsEvent, extra: extra)

        let inputSource = extra["input_source"] as? String
        let suggestionIndex = extra["suggestion_index"] as? Int
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
            await fetchNarrative(
                context: context,
                prompt: prompt,
                turnID: turnID,
                startedAt: startedAt,
                inputSource: inputSource,
                suggestionIndex: suggestionIndex
            )
        }
        coordinator?.replacePendingNarrativeFetch(narrativeTask)
    }

    private func fetchNarrative(
        context: DungeonMasterTurnContext,
        prompt: PlayerPromptID,
        turnID: String,
        startedAt: Date,
        inputSource: String?,
        suggestionIndex: Int?
    ) async {
        defer {
            coordinator?.clearPendingNarrativeFetch()
            loading = false
            persistRun()
            onCompletedPlayerAction?()
        }

        do {
            let turn = try await dungeonMaster.generate(
                context: context,
                analyticsContext: aiContext(
                    turnID: turnID,
                    inputSource: inputSource,
                    suggestionIndex: suggestionIndex
                )
            )
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
            if let scene = result.scene {
                let caption = SceneCaption.compose(scene, memory: &sceneMemory)
                Task {
                    await handleVisionAfterTurn(visualPrompt: caption, prompt: prompt, turnID: turnID)
                }
            }
        } catch {
            var failureProperties: [String: Any] = [
                "turn_id": turnID,
                "turn_kind": context.kind.rawValue,
                "duration": Date().timeIntervalSince(startedAt),
                "error_kind": error.analyticsKind,
            ]
            if let detail = error.analyticsDetail {
                failureProperties["error_detail"] = detail
            }
            capture("dm_turn_failed", extra: failureProperties)
            appendSystemMessage(error.terminalMessage)
        }
    }

    func dungeonMasterTurnContext(
        kind: DungeonMasterTurnKind,
        playerMessage: String,
        diceRoll: Int?
    ) -> DungeonMasterTurnContext {
        DungeonMasterTurnContext(
            kind: kind,
            playerMessage: playerMessage,
            health: health,
            maxHealth: maxHealth,
            mana: mana,
            maxMana: maxMana,
            storySoFar: terminalEntries,
            diceRoll: diceRoll
        )
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
                if health == 0, healthBefore > 0 {
                    capture(
                        "player_defeated",
                        extra: [
                            "amount": amount,
                            "health_before": healthBefore,
                        ]
                    )
                    if persistRunsToLibrary {
                        incrementStoredCounter("runsDefeats")
                    }
                }
            case let .changeMana(amount):
                let manaBefore = mana
                mana = min(maxMana, max(0, mana + amount))
                capture(
                    "dm_mana_changed",
                    extra: [
                        "amount": amount,
                        "mana_before": manaBefore,
                        "mana_after": mana,
                        "mana_delta": mana - manaBefore,
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

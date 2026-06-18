//
//  GameViewModel+Dice.swift
//  magoSanduiche
//

import Foundation
import SwiftUI

extension GameViewModel {
    func rollDice(reduceMotion: Bool = false) {
        guard !loading else { return }
        guard pendingDiceRoll == nil else { return }

        loading = true
        uiPhase = .rollingDice
        diceResultText = String(localized: "nan_dice_rolling")
        capture("dice_roll_started")

        diceRevealStage = .scrambling

        Task {
            await performDiceRevealAnimation(reduceMotion: reduceMotion)
        }
    }

    func commitDiceRollOutcome() {
        guard let roll = pendingDiceRoll else { return }
        guard !loading else { return }
        pendingDiceRoll = nil

        diceResultText = revealedDiceRollText(for: roll)
        let outcome = DiceOutcomeTier(roll: roll).analyticsName
        capture("dice_roll_completed", extra: ["roll": roll, "outcome": outcome])

        coordinator?.finishDicePrompt()

        let context = dungeonMasterTurnContext(
            kind: .diceResultConfirmation,
            playerMessage: "",
            diceRoll: roll,
            diceOutcomeSummary: nil
        )
        beginDungeonMasterTurn(
            displayText: String(format: String(localized: "nan_dice_player_confirmed"), roll),
            context: context,
            analyticsEvent: "dice_result_submitted",
            extraAnalytics: ["roll": roll, "outcome": outcome]
        )
    }

    private func performDiceRevealAnimation(reduceMotion: Bool) async {
        let finalRoll = Int.random(in: 1 ... 20)

        if reduceMotion {
            diceValue = Int.random(in: 1 ... 20)
        } else {
            for step in 0 ..< DiceRollRevealTiming.scrambleTicks {
                diceValue = Int.random(in: 1 ... 20)
                try? await Task.sleep(for: .milliseconds(DiceRollRevealTiming.scrambleSleepMillis(step: step)))
            }
        }

        withAnimation(TerminalMotion.diceFadeAnimation(reduceMotion: reduceMotion)) {
            diceRevealStage = .fadingOut
        }
        try? await Task.sleep(for: .seconds(DiceRollRevealTiming.fadeOutSeconds(reduceMotion: reduceMotion)))

        var settleTransaction = Transaction()
        settleTransaction.disablesAnimations = true
        withTransaction(settleTransaction) {
            diceValue = finalRoll
            diceRevealStage = .suspense
        }

        try? await Task.sleep(for: .seconds(DiceRollRevealTiming.suspenseSeconds(reduceMotion: reduceMotion)))

        TerminalHaptics.playDiceReveal(roll: finalRoll)
        withAnimation(TerminalMotion.diceRevealAnimation(reduceMotion: reduceMotion)) {
            diceRevealStage = .bamReveal
        }
        diceResultText = revealedDiceRollText(for: finalRoll)
        try? await Task.sleep(for: .seconds(DiceRollRevealTiming.bamRevealSeconds(reduceMotion: reduceMotion)))

        pendingDiceRoll = finalRoll
        loading = false
        uiPhase = .result

        var idleTransaction = Transaction()
        idleTransaction.disablesAnimations = true
        withTransaction(idleTransaction) {
            diceRevealStage = .idle
        }
        persistRun()
    }

    private func revealedDiceRollText(for roll: Int) -> String {
        String(format: String(localized: "nan_dice_roll_revealed"), roll)
    }
}

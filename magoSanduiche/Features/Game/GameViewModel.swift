//
//  GameViewModel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.
//

import CoreGraphics
import Foundation
import SwiftData
import SwiftUI

#if canImport(UIKit)
	import UIKit
#endif

@Observable
@MainActor
final class GameViewModel {
	private weak var coordinator: AppCoordinator?
	private let imageGenService = ImageGenerator(concept: "An old wizard eating a sandwich")
	private(set) var gameSessionID: String
	private var dungeonMaster: DungeonMasterService?

	/// When set, `persistRun()` writes to the shared SwiftData store (`LoadRunView`).
	var modelContext: ModelContext?
	/// Persist to the run library (off for onboarding demo).
	let persistRunsToLibrary: Bool
	/// Stable id for the `StoredGameRun` row once created.
	private(set) var persistedRunID: UUID?
	/// Plain transcript for loaded runs; cleared on the next player submission.
	var suppressTerminalAnimations = false
	/// DM requested a roll; dice chrome is shown after the latest narrative typewriter finishes.
	private(set) var shouldShowDicePromptAfterNarrative = false

	var loading = false
	var selectedImage: CGImage?
	var contextAction: GameAction = .write
	var uiPhase: GameUIPhase = .reading
	var health = 10
	var mana = 14
	var maxHealth = 18
	var maxMana = 18
	var diceValue = 20
	var diceRevealStage = DiceRevealStage.idle
	/// After reveal animation; DM turn is sent only after `commitDiceRollOutcome()`.
	var pendingDiceRoll: Int?
	var diceResultText = String(localized: "nan_dice_idle_cold")
	var invalidInputAttempts = 0
	var contextualInput = ""
	/// Lettered options from the last DM `PromptOutput`, shown as tappable shortcuts above the text field.
	var suggestedOptions: [String] = []
	var onCompletedPlayerAction: (() -> Void)?
	var terminalEntries: [TerminalEntry] = [
		TerminalEntry(kind: .dungeonMaster, text: Introduction.intro)
	]

	init(coordinator: AppCoordinator? = nil, persistRunsToLibrary: Bool = true) {
		self.coordinator = coordinator
		self.gameSessionID = UUID().uuidString
		self.persistRunsToLibrary = persistRunsToLibrary
		self.dungeonMaster = try? DungeonMasterService()
		AppAnalytics.capture(
			"game_session_started",
			properties: [
				"game_session_id": gameSessionID,
				"has_dungeon_master": dungeonMaster != nil,
				"health": health,
				"mana": mana,
				"max_health": maxHealth,
				"max_mana": maxMana,
				"persist_runs": persistRunsToLibrary,
			])
	}

	func attachCoordinator(_ coordinator: AppCoordinator) {
		self.coordinator = coordinator
	}

	/// Loads a saved run from SwiftData. Call from `GameView` when resuming.
	func restore(runID: UUID, modelContext: ModelContext) {
		guard let stored = GameRunSnapshotMapper.fetch(id: runID, context: modelContext) else { return }
		self.modelContext = modelContext
		persistedRunID = stored.id
		gameSessionID = stored.analyticsSessionID
		do {
			let lines = try GameRunSnapshotMapper.decodeTranscript(from: stored.transcriptBlob)
			if lines.isEmpty {
				terminalEntries = [TerminalEntry(kind: .dungeonMaster, text: Introduction.intro)]
			} else {
				terminalEntries = lines.map {
					TerminalEntry(id: $0.id, kind: $0.kind.terminalKind, text: $0.text)
				}
			}
		} catch {
			terminalEntries = [TerminalEntry(kind: .dungeonMaster, text: Introduction.intro)]
		}

		health = stored.health
		mana = stored.mana
		maxHealth = stored.maxHealth
		maxMana = stored.maxMana
		diceValue = stored.diceValue
		pendingDiceRoll = stored.pendingDiceRoll
		diceRevealStage = GameRunSnapshotMapper.diceRevealStage(from: stored.diceRevealStageRaw)
		diceResultText = stored.diceResultText
		invalidInputAttempts = stored.invalidInputAttempts
		contextualInput = stored.contextualInput
		contextAction = GameRunSnapshotMapper.contextAction(from: stored.contextActionRaw)
		uiPhase = GameRunSnapshotMapper.uiPhase(from: stored.uiPhaseRaw)
		suggestedOptions = GameRunSnapshotMapper.decodeSuggestedOptions(from: stored.suggestedOptionsBlob)
		suppressTerminalAnimations = stored.suppressTerminalAnimations
		dungeonMaster = try? DungeonMasterService()
	}

	func saveSnapshot(modelContext: ModelContext) {
		self.modelContext = modelContext
		persistRun()
	}

	private func persistRun() {
		guard persistRunsToLibrary, let modelContext else { return }

		do {
			let now = Date()
			let id = persistedRunID ?? UUID()
			let existing = GameRunSnapshotMapper.fetch(id: id, context: modelContext)
			let createdAt = existing?.createdAt ?? now

			let persistedLines = GameRunSnapshotMapper.persistedLines(from: terminalEntries)
			let transcriptBlob = try GameRunSnapshotMapper.encodeTranscript(persistedLines)
			let suggestedBlob = try GameRunSnapshotMapper.encodeSuggestedOptions(suggestedOptions)
			let title = GameRunSnapshotMapper.displayTitle(entries: terminalEntries, fallback: createdAt)

			if let existing {
				existing.updatedAt = now
				existing.displayTitle = title
				existing.transcriptBlob = transcriptBlob
				existing.health = health
				existing.mana = mana
				existing.maxHealth = maxHealth
				existing.maxMana = maxMana
				existing.diceValue = diceValue
				existing.pendingDiceRoll = pendingDiceRoll
				existing.diceRevealStageRaw = GameRunSnapshotMapper.diceRevealStageRaw(diceRevealStage)
				existing.diceResultText = diceResultText
				existing.invalidInputAttempts = invalidInputAttempts
				existing.contextualInput = contextualInput
				existing.contextActionRaw = GameRunSnapshotMapper.contextActionRaw(contextAction)
				existing.uiPhaseRaw = GameRunSnapshotMapper.uiPhaseRaw(uiPhase)
				existing.suggestedOptionsBlob = suggestedBlob
				existing.suppressTerminalAnimations = suppressTerminalAnimations
				existing.schemaVersion = GameRunPersistSchema.currentVersion
				existing.analyticsSessionID = gameSessionID
			} else {
				let inserted = StoredGameRun(
					id: id,
					createdAt: createdAt,
					updatedAt: now,
					displayTitle: title,
					transcriptBlob: transcriptBlob,
					health: health,
					mana: mana,
					maxHealth: maxHealth,
					maxMana: maxMana,
					diceValue: diceValue,
					pendingDiceRoll: pendingDiceRoll,
					diceRevealStageRaw: GameRunSnapshotMapper.diceRevealStageRaw(diceRevealStage),
					diceResultText: diceResultText,
					invalidInputAttempts: invalidInputAttempts,
					contextualInput: contextualInput,
					contextActionRaw: GameRunSnapshotMapper.contextActionRaw(contextAction),
					uiPhaseRaw: GameRunSnapshotMapper.uiPhaseRaw(uiPhase),
					suggestedOptionsBlob: suggestedBlob,
					suppressTerminalAnimations: suppressTerminalAnimations,
					isEphemeralTutorial: false,
					schemaVersion: GameRunPersistSchema.currentVersion,
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

	func getImage() {
		Task {
			loading = true
			defer { loading = false }

			guard let firstImage = await imageGenService.generateImage()?.first else { return }
			selectedImage = firstImage
		}
	}

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

	func registerEmptyInput() {
		invalidInputAttempts += 1
		uiPhase = .composing
		AppAnalytics.capture(
			"player_empty_input_submitted",
			properties: [
				"game_session_id": gameSessionID,
				"invalid_input_attempts": invalidInputAttempts,
			])
	}

	func rollDice(reduceMotion: Bool = false) {
		guard !loading else { return }
		guard pendingDiceRoll == nil else { return }

		loading = true
		uiPhase = .rollingDice
		diceResultText = String(localized: "nan_dice_rolling")
		AppAnalytics.capture(
			"dice_roll_started",
			properties: [
				"game_session_id": gameSessionID,
				"health": health,
				"mana": mana,
			])

		diceRevealStage = .scrambling

		Task {
			let finalRoll = Int.random(in: 1...20)

			if reduceMotion {
				diceValue = Int.random(in: 1...20)
			} else {
				for step in 0..<DiceRollRevealTiming.scrambleTicks {
					diceValue = Int.random(in: 1...20)
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
			updateDiceOutcomePreview(for: finalRoll)
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
	}

	func commitDiceRollOutcome() {
		guard let roll = pendingDiceRoll else { return }
		guard !loading else { return }
		pendingDiceRoll = nil

		diceResultText = String(format: String(localized: "nan_dice_roll_revealed"), roll)
		AppAnalytics.capture(
			"dice_roll_completed",
			properties: [
				"game_session_id": gameSessionID,
				"roll": roll,
				"outcome": diceOutcomeName(for: roll),
				"health": health,
				"mana": mana,
			])

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
			extraAnalytics: ["roll": roll, "outcome": diceOutcomeName(for: roll)]
		)
	}

	private func dungeonMasterTurnContext(
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

	private func beginDungeonMasterTurn(
		displayText: String,
		context: DungeonMasterTurnContext,
		analyticsEvent: String,
		extraAnalytics: [String: Any] = [:]
	) {
		suppressTerminalAnimations = false
		suggestedOptions = []
		loading = true
		uiPhase = .awaitingDungeonMaster
		terminalEntries.append(TerminalEntry(kind: .player, text: displayText))
		contextualInput = ""

		let turnID = UUID().uuidString
		let startedAt = Date()
		var properties: [String: Any] = [
			"game_session_id": gameSessionID,
			"turn_id": turnID,
			"turn_kind": context.kind.rawValue,
			"terminal_entry_count": terminalEntries.count,
			"health": health,
			"mana": mana,
		]
		for (key, value) in extraAnalytics {
			properties[key] = value
		}
		AppAnalytics.capture(analyticsEvent, properties: properties)

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
		loading = true
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
					analyticsContext: AIAnalyticsContext(sessionID: gameSessionID, turnID: turnID)
				)
			else {
				appendSystemMessage(String(localized: "nan_dm_silent"))
				AppAnalytics.capture(
					"dm_turn_empty_response",
					properties: [
						"game_session_id": gameSessionID,
						"turn_id": turnID,
						"duration": Date().timeIntervalSince(startedAt),
					])
				return
			}

			let result = turn.output
			let normalizedOptions = result.options
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }
			terminalEntries.append(TerminalEntry(kind: .dungeonMaster, text: result.narrative))
			suppressTerminalAnimations = false
			uiPhase = .result
			applyToolEffects(turn.toolEffects)
			suggestedOptions = normalizedOptions
			AppAnalytics.capture(
				"dm_turn_succeeded",
				properties: [
					"game_session_id": gameSessionID,
					"turn_id": turnID,
					"turn_kind": context.kind.rawValue,
					"duration": Date().timeIntervalSince(startedAt),
					"narrative_length": result.narrative.count,
					"suggested_option_count": suggestedOptions.count,
					"terminal_entry_count": terminalEntries.count,
				])
		} catch {
			AppAnalytics.capture(
				"dm_turn_failed",
				properties: [
					"game_session_id": gameSessionID,
					"turn_id": turnID,
					"turn_kind": context.kind.rawValue,
					"duration": Date().timeIntervalSince(startedAt),
					"error_type": String(describing: type(of: error)),
					"error_message": error.localizedDescription,
				])
			appendSystemMessage(String(localized: "nan_dm_error"))
		}
	}

	private func appendSystemMessage(_ text: String) {
		terminalEntries.append(TerminalEntry(kind: .system, text: text))
		uiPhase = .result
	}

	private func updateDiceOutcomePreview(for roll: Int) {
		diceResultText = String(format: String(localized: "nan_dice_roll_revealed"), roll)
	}

	private func diceOutcomeName(for roll: Int) -> String {
		switch roll {
		case 1...6:
			"low"
		case 7...14:
			"mid"
		default:
			"high"
		}
	}

	private func applyToolEffects(_ effects: [GameToolEffect]) {
		for effect in effects {
			applyToolEffect(effect)
		}
	}

	private func applyToolEffect(_ effect: GameToolEffect) {
		switch effect {
		case .requestAction(let action):
			applyRequestedAction(action)
		case .changeHealth(let amount):
			let healthBefore = health
			health = min(maxHealth, max(0, health + amount))
			AppAnalytics.capture(
				"dm_health_changed",
				properties: [
					"game_session_id": gameSessionID,
					"amount": amount,
					"health_before": healthBefore,
					"health_after": health,
					"health_delta": health - healthBefore,
				])
		}
	}

	private func revealDeferredDicePromptIfNeeded() {
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
			AppAnalytics.capture(
				"dm_action_requested",
				properties: [
					"game_session_id": gameSessionID,
					"action": "write",
				])
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
			AppAnalytics.capture(
				"dm_action_requested",
				properties: [
					"game_session_id": gameSessionID,
					"action": "roll",
				])
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

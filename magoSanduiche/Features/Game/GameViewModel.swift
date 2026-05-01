//
//  GameViewModel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.
//

import CoreGraphics
import Foundation

@Observable
@MainActor
final class GameViewModel {
	private weak var coordinator: AppCoordinator?
	private let imageGenService = ImageGenerator(concept: "An old wizard eating a sandwich")
	private var dungeonMaster: DungeonMasterService?

	var loading = false
	var selectedImage: CGImage?
	var hasCompletedInitialText = false
	var contextAction: GameAction = .write
	var uiPhase: GameUIPhase = .reading
	var health = 10
	var mana = 14
	var maxHealth = 18
	var maxMana = 18
	var diceValue = 20
	var diceResultText = "The die is cold. It waits for your hand."
	var invalidInputAttempts = 0
	var contextualInput = ""
	var terminalEntries: [TerminalEntry] = [
		TerminalEntry(kind: .dungeonMaster, text: Introduction.intro)
	]

	var narrativeText: String {
		terminalEntries.map(\.renderedText).joined(separator: "\n\n")
	}

	init(coordinator: AppCoordinator? = nil) {
		self.coordinator = coordinator
		self.dungeonMaster = try? DungeonMasterService(actionCallback: handleAction)
	}

	func attachCoordinator(_ coordinator: AppCoordinator) {
		self.coordinator = coordinator
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

		loading = true
		uiPhase = .awaitingDungeonMaster
		terminalEntries.append(TerminalEntry(kind: .player, text: trimmed))
		contextualInput = ""

		Task {
			await fetchNarrative(for: trimmed)
		}

		return true
	}

	func markNarrativeFinished() {
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
	}

	func rollDice() {
		guard !loading else { return }

		loading = true
		uiPhase = .rollingDice
		diceResultText = "The die rattles across the dungeon floor..."

		Task {
			for _ in 0..<12 {
				diceValue = Int.random(in: 1...20)
				try? await Task.sleep(for: .milliseconds(55))
			}

			let finalRoll = Int.random(in: 1...20)
			diceValue = finalRoll
			resolveDiceRoll(finalRoll)
			contextAction = .write
			coordinator?.finishDicePrompt()
			loading = false
			uiPhase = .result
		}
	}

	private func fetchNarrative(for prompt: String) async {
		loading = true
		defer { loading = false }

		do {
			guard let result = try await dungeonMaster?.generate(prompt) else {
				appendSystemMessage("The dungeon master remains silent.")
				return
			}

			terminalEntries.append(TerminalEntry(kind: .dungeonMaster, text: result.narrative))
			uiPhase = .result
		} catch {
			appendSystemMessage("The dungeon master could not respond this time.")
		}
	}

	private func appendSystemMessage(_ text: String) {
		terminalEntries.append(TerminalEntry(kind: .system, text: text))
		uiPhase = .result
	}

	private func resolveDiceRoll(_ roll: Int) {
		let outcome: String
		switch roll {
		case 1...6:
			health = max(0, health - 2)
			outcome = "A brutal \(roll). The dungeon bites back. HP -2."
		case 7...14:
			outcome = "A tense \(roll). You hold your ground, but the dark notices you."
		default:
			mana = min(maxMana, mana + 2)
			outcome = "A bright \(roll). Arcane luck surges through your staff. MP +2."
		}

		diceResultText = outcome
		terminalEntries.append(TerminalEntry(kind: .dice, text: outcome))
	}

	private func handleAction(_ option: Int) {
		Task { @MainActor in
			switch option {
			case 0:
				contextAction = .write
				uiPhase = .composing
				coordinator?.prepareForTextInput()
			case 1:
				contextAction = .roll
				uiPhase = .rollingDice
				coordinator?.showDicePrompt()
			default:
				contextAction = .write
				uiPhase = .ready
				coordinator?.resetActionPresentation()
			}
		}
	}
}

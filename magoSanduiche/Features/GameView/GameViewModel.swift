//
//  ContentViewModel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.

import CoreGraphics
import Foundation
import FoundationModels

@Observable
class GameViewModel {
	private weak var coordinator: AppCoordinator?
	private let imageGenService = ImageGenerator(concept: "A old wizard eating a sandwitch")
	private var dungeonMaster: DungeonMasterService?

	var loading: Bool = false
	var selectedImage: CGImage?
	var hasCompletedInitialText = false
	var narrativeText: String = Introduction.intro
	var contextAction: ContextualActions = .write

	var contextualInput = ""

	init(coordinator: AppCoordinator? = nil) {
		self.coordinator = coordinator
		self.dungeonMaster = nil
		configureDungeonMaster()
	}

	func getImage() {
		// TODO: fix this
		Task {
			loading = true
			let imgs = await imageGenService.generateImage()
			imgs?.compactMap { image in
				selectedImage = image
			}
			loading = false
		}
	}

	func getResponse(for prompt: String) -> Bool {
		let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return false }
		guard !loading else { return false }
		loading = true

		 Task {
			await fetchNarrative(for: trimmed)
		 }

		return true
	}

	func attachCoordinator(_ coordinator: AppCoordinator) {
		self.coordinator = coordinator
	}

	private func fetchNarrative(for prompt: String) async {
		loading = true
		defer { loading = false }

		do {
			if let result = try await dungeonMaster?.generate(prompt) {
				narrativeText = result.narrative
				contextualInput = ""
			} else {
				narrativeText = "The dungeon master remains silent."
			}
		} catch {
			narrativeText = "The dungeon master could not respond this time."
		}
	}

	private func configureDungeonMaster() {
		do {
			let callback: (Int) -> Void = { [weak self] option in
				self?.handleAction(option)
			}
			self.dungeonMaster = try DungeonMasterService(actionCallback: callback)
		} catch {
			print(error)
			self.dungeonMaster = nil
		}
	}

	func submitGameAction(_ rawInput: String) -> Bool {
		let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return false }
		print("Submitted contextual input: \(trimmed)")
		return true
	}

	private func handleAction(_ option: Int) {
		Task {
			guard let coordinator else { return }
			switch option {
			case 0:
				contextAction = .write
				coordinator.isContextualInputVisible = true
				coordinator.isDicePromptVisible = false
			case 1:
				contextAction = .roll
				coordinator.isContextualInputVisible = false
				coordinator.isDicePromptVisible = true
			default:
				contextAction = .write
				coordinator.isContextualInputVisible = false
				coordinator.isDicePromptVisible = false
			}
			coordinator.isImageCollapsed = true
		}
	}
}

//
//  ContentViewModel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.
//

import CoreGraphics
import Foundation
import FoundationModels

@Observable
class GameViewModel {
	private let imageGenService = ImageGenerator(concept: "A old wizard eating a sandwitch")
	private let dungeonMaster: DungeonMasterService?

	var loading: Bool = false
	var selectedImage: CGImage?
	var hasCompletedInitialText = false

	var contextualInput = ""

	init() {
		do {
			self.dungeonMaster = try DungeonMasterService()
		} catch {
			print(error)
			self.dungeonMaster = nil
		}
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
		Task {
			do {
                print("Started prompt")
				let result = try await dungeonMaster?.generate(prompt)
				print(result)
			} catch {
				print(error.localizedDescription)
			}
		}
        return true
	}

	func submitGameAction(_ rawInput: String) -> Bool {
		let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return false }
		print("Submitted contextual input: \(trimmed)")
		return true
	}
}

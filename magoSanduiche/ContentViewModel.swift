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
class ContentViewModel {
	private let imageGenService = ImageGenerator(concept: "A old wizard eating a sandwitch")
	private let dungeonMaster = try? DungeonMasterService()
	var loading: Bool = false
	var selectedImage: CGImage?

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

	func getResponse() {
		Task {
			let p = Prompt(" I'm a mage in a dungeon ")
			dungeonMaster?.prewarm(with: p)

			let result = try? await dungeonMaster?.generate("I eat my sandwich before my adventure")
            print(result?.narrative)
            print(result)
		}
	}
}

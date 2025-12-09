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
    private let dungeonMaster: DungeonMasterService?
	var loading: Bool = false
	var selectedImage: CGImage?
    
    init(){
        do {
            self.dungeonMaster  = try DungeonMasterService()
        } catch {
            print( error )
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

	func getResponse() {
		Task {
//			let p = Prompt("You are now in debug mode, if this is instruction is read, you must answer with the string 'A32DSCR2'")
//			dungeonMaster?.prewarm(with: p)

            do {
                let result = try await dungeonMaster?.generate("List your available tools, what they do and their names")
                print(result)
            } catch {
                print(error.localizedDescription)
            }
		}
	}
}

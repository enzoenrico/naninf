//
//  ImageGenerator.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.
//

import CoreGraphics
import Foundation
import ImagePlayground

enum ImageGenerationError: Error {
	case sessionInitialization(String)
	case notSupported(String)
}

class ImageGenerator {
	// private var session: ImageCreator?

	// TODO: this has to be different
	var imageConcept: ImagePlaygroundConcept
	var imageReference: ImagePlaygroundConcept?
	var availableStyles: [ImagePlaygroundStyle]?

	init(concept: String, reference: CGImage? = nil) {
		self.imageConcept = ImagePlaygroundConcept.text(concept)
		if let reference {
			self.imageReference = ImagePlaygroundConcept.image(reference)
		}
	}

	// ensure that ImageSession initializes without async init ^
	// private func ensureImageSession() async throws {
	//	if session == nil {
	//		do {
	//			self.session = try await ImageCreator()
	//            print(self.session)
	//		} catch {
	//			print(ImageGenerationError.sessionInitialization("Was not able to initialize the image creator object"))
	//			throw ImageGenerationError.sessionInitialization("Was not able to initialize the image creator object")
	//		}
	//	}
	// }

	func generateImage() async -> [CGImage]? {
		// try? await ensureImageSession()
		do {
			let session = try await ImageCreator()
			var candidates: [CGImage] = []
			guard let style = session.availableStyles.first else { return nil }
			let chulingas = session.images(
 				for: [.text("A cat wearing mittens")],
				style: style,
				limit: 1
			)
			do {
				for try await bingas in chulingas {
					let anImage = bingas.cgImage
					print(anImage)
					candidates.append(anImage)
				}
			} catch {
				print(error.localizedDescription)
				print(ImageGenerationError.notSupported("Image generation not supported :("))
				return nil
			}
		} catch {
			print("session not started")
		}

		return nil
	}

}

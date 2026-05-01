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

final class ImageGenerator {
	var imageConcept: ImagePlaygroundConcept
	var imageReference: ImagePlaygroundConcept?

	init(concept: String, reference: CGImage? = nil) {
		self.imageConcept = .text(concept)
		if let reference {
			self.imageReference = .image(reference)
		}
	}

	func generateImage() async -> [CGImage]? {
		do {
			let session = try await ImageCreator()
			guard let style = session.availableStyles.first else { return nil }

			let concepts = [imageConcept] + [imageReference].compactMap { $0 }
			var candidates: [CGImage] = []

			for try await image in session.images(
				for: concepts,
				style: style,
				limit: 1
			) {
				candidates.append(image.cgImage)
			}

			return candidates.isEmpty ? nil : candidates
		} catch {
			return nil
		}
	}
}

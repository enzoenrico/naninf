//
//  SceneIllustrator.swift
//  magoSanduiche
//

import CoreGraphics
import Foundation
import ImagePlayground

protocol SceneIllustrator {
	func illustrate(_ prompt: String) async throws -> CGImage
}

struct ImagePlaygroundIllustrator: SceneIllustrator {
	func illustrate(_ prompt: String) async throws -> CGImage {
		let creator = try await ImageCreator()
		let style = creator.availableStyles.contains(.sketch) ? ImagePlaygroundStyle.sketch : creator.availableStyles.first
		guard let style else { throw SceneMediaError.unavailable }

		for try await image in creator.images(for: [.text(prompt)], style: style, limit: 1) {
			return image.cgImage
		}
		throw SceneMediaError.noImage
	}
}

#if DEBUG
	struct ScriptedIllustrator: SceneIllustrator {
		func illustrate(_ prompt: String) async throws -> CGImage {
			_ = prompt
			let colorSpace = CGColorSpaceCreateDeviceGray()
			guard
				let context = CGContext(
					data: nil,
					width: 1,
					height: 1,
					bitsPerComponent: 8,
					bytesPerRow: 1,
					space: colorSpace,
					bitmapInfo: CGImageAlphaInfo.none.rawValue
				),
				let image = context.makeImage()
			else {
				throw SceneMediaError.noImage
			}
			return image
		}
	}
#endif

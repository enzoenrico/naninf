//
//  SceneIllustrator.swift
//  magoSanduiche
//

import CoreGraphics
import Foundation
import ImageIO
import ImagePlayground

protocol SceneIllustrator {
	func illustrate(_ prompt: String) async throws -> CGImage
	func illustrate(_ prompt: String, progress: SceneIllustrationProgress) async throws -> CGImage
	var illustratesWithSystemSheet: Bool { get }
}

extension SceneIllustrator {
	var illustratesWithSystemSheet: Bool { false }

	func illustrate(_ prompt: String, progress: SceneIllustrationProgress) async throws -> CGImage {
		_ = progress
		return try await illustrate(prompt)
	}
}

/// Fraction of a scene render, from 0 to 1. Safe to call off the main actor.
nonisolated struct SceneIllustrationProgress: Sendable {
	private let report: @Sendable (Double) -> Void

	init(_ report: @escaping @Sendable (Double) -> Void = { _ in }) {
		self.report = report
	}

	static let ignored = SceneIllustrationProgress()

	func update(_ fraction: Double) {
		report(min(1, max(0, fraction)))
	}
}

enum SceneImageGeneration {
	/// Image Playground cannot return a bitmap without its system sheet. Keep generation off until a direct API exists.
	static let isLocked = true
}

enum ScenePlaygroundConfiguration {
	static var options: ImagePlaygroundOptions {
		var options = ImagePlaygroundOptions()
		options.personalization = .disabled
		options.creationStrategy = .generateNew
		return options
	}
}

enum SceneImageLoader {
	static func cgImage(at url: URL) throws -> CGImage {
		let didAccess = url.startAccessingSecurityScopedResource()
		defer {
			if didAccess {
				url.stopAccessingSecurityScopedResource()
			}
		}
		guard
			let source = CGImageSourceCreateWithURL(url as CFURL, nil),
			let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
		else {
			throw SceneMediaError.noImage
		}
		return image
	}
}

/// Scene art from `carlofkl/DreamLite-mobile`, generated on device. The ASCII renderer only needs the bitmap.
struct DreamLiteIllustrator: SceneIllustrator {
	let generator: any DreamLiteImageGenerating

	init(generator: (any DreamLiteImageGenerating)? = nil) {
		self.generator = generator ?? DreamLiteOnDeviceGenerator.shared
	}

	func illustrate(_ prompt: String) async throws -> CGImage {
		try await illustrate(prompt, progress: .ignored)
	}

	func illustrate(_ prompt: String, progress: SceneIllustrationProgress) async throws -> CGImage {
		try await generator.generateImage(prompt: prompt, progress: progress)
	}
}

/// iOS 27 discontinued `ImageCreator`. Scene art is created in the system Image Playground sheet.
struct ImagePlaygroundIllustrator: SceneIllustrator {
	var illustratesWithSystemSheet: Bool { true }

	func illustrate(_ prompt: String) async throws -> CGImage {
		_ = prompt
		throw SceneMediaError.unavailable
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

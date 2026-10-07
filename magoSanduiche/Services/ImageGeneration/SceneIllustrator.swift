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
	var illustratesWithSystemSheet: Bool { get }
}

extension SceneIllustrator {
	var illustratesWithSystemSheet: Bool { false }
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

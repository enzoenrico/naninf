//
//  SceneMediaResource.swift
//  magoSanduiche
//

import CoreGraphics
import Foundation

nonisolated struct SceneImage: Sendable, Equatable {
	let id: UUID
	let cgImage: CGImage

	init(cgImage: CGImage, id: UUID = UUID()) {
		self.id = id
		self.cgImage = cgImage
	}

	static func == (lhs: SceneImage, rhs: SceneImage) -> Bool {
		lhs.id == rhs.id
	}
}

nonisolated enum SceneMediaError: Error, LocalizedError, Equatable {
	case emptyPrompt
	case unavailable
	case noImage

	var errorDescription: String? {
		switch self {
		case .emptyPrompt:
			String(localized: "nan_vision_error_empty_prompt")
		case .unavailable:
			String(localized: "nan_vision_error_unavailable")
		case .noImage:
			String(localized: "nan_vision_error_no_image")
		}
	}

	var analyticsKind: String {
		switch self {
		case .emptyPrompt:
			"empty_prompt"
		case .unavailable:
			"unavailable"
		case .noImage:
			"no_image"
		}
	}
}

nonisolated enum VisionDisplayMode: Equatable {
	static let introPlaceholderCatalogName = "mageOpening"

	case introStatic
	case scene(SceneImage)
	case recalled(PlayerPromptID, SceneImage)

	var recalledPrompt: PlayerPromptID? {
		if case .recalled(let prompt, _) = self {
			return prompt
		}
		return nil
	}

	var onScreenImageID: UUID? {
		switch self {
		case .introStatic:
			nil
		case .scene(let image), .recalled(_, let image):
			image.id
		}
	}
}

/// The vision placeholder video is 1280×720. Scene art is shown in that same 16:9 frame.
enum SceneFrame {
	static let widthOverHeight = 16.0 / 9.0

	/// Center-crops to 16:9. DreamLite's converted canvas is square; the band that matches the placeholder is what the panel shows.
	static func widescreen(_ image: CGImage) -> CGImage {
		let width = image.width
		let height = image.height
		guard width > 1, height > 1 else { return image }

		let current = Double(width) / Double(height)
		guard abs(current - widthOverHeight) > 0.01 else { return image }

		let rect: CGRect
		if current > widthOverHeight {
			let croppedWidth = max(1, Int((Double(height) * widthOverHeight).rounded()))
			let x = max(0, (width - croppedWidth) / 2)
			rect = CGRect(x: x, y: 0, width: min(croppedWidth, width - x), height: height)
		} else {
			let croppedHeight = max(1, Int((Double(width) / widthOverHeight).rounded()))
			let y = max(0, (height - croppedHeight) / 2)
			rect = CGRect(x: 0, y: y, width: width, height: min(croppedHeight, height - y))
		}
		return image.cropping(to: rect) ?? image
	}
}

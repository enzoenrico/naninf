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
}

nonisolated enum VisionDisplayMode: Equatable {
	static let introPlaceholderCatalogName = "mageOpening"

	case introStatic
	case scene(SceneImage)
}

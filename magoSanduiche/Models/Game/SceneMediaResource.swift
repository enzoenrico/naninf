//
//  SceneMediaResource.swift
//  magoSanduiche
//

import Foundation

enum SceneMediaKind: String, Sendable {
	case image
	case video
}

struct SceneMediaResource: Sendable, Equatable {
	let url: URL
	let kind: SceneMediaKind
}

enum SceneMediaError: Error, LocalizedError {
	case emptyPrompt
	case noImageURL
	case invalidImageURL

	var errorDescription: String? {
		switch self {
		case .emptyPrompt:
			String(localized: "nan_vision_error_empty_prompt")
		case .noImageURL:
			String(localized: "nan_vision_error_no_url")
		case .invalidImageURL:
			String(localized: "nan_vision_error_invalid_url")
		}
	}
}

enum VisionDisplayMode: Equatable {
	case introStatic
	case remote(SceneMediaResource)
}

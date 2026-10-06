//
//  DungeonMasterService.swift
//  magoSanduiche
//

import Foundation

nonisolated enum DungeonMasterTurnValidation {
	static let minimumOptionCount = 3

	static let fallbackOptions: [String] = [
		String(localized: "nan_dm_fallback_option_explore"),
		String(localized: "nan_dm_fallback_option_observe"),
		String(localized: "nan_dm_fallback_option_caution"),
	]

	static func normalizedOptions(from options: [String]) -> [String] {
		options
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}

	static func paddedOptions(from options: [String]) -> [String] {
		var result = normalizedOptions(from: options)
		guard result.count < minimumOptionCount else {
			return Array(result.prefix(minimumOptionCount))
		}

		for fallback in fallbackOptions where result.count < minimumOptionCount {
			if !result.contains(fallback) {
				result.append(fallback)
			}
		}

		while result.count < minimumOptionCount {
			result.append(
				String(
					format: String(localized: "nan_dm_fallback_option_generic"),
					result.count + 1
				)
			)
		}

		return Array(result.prefix(minimumOptionCount))
	}
}

@MainActor
final class DungeonMasterService {
	private let narrator: any DungeonNarrator
	private let illustrator: any SceneIllustrator

	init(
		narrator: (any DungeonNarrator)? = nil,
		illustrator: (any SceneIllustrator)? = nil
	) {
		self.narrator = narrator ?? Self.defaultNarrator()
		self.illustrator = illustrator ?? ImagePlaygroundIllustrator()
	}

	func generate(
		context: DungeonMasterTurnContext,
		analyticsContext: AIAnalyticsContext? = nil
	) async throws(DungeonMasterError) -> DungeonMasterTurn {
		let prompt = DungeonMasterTurnFormatter.format(context)
		let draft = try await narrator.draft(for: prompt, analyticsContext: analyticsContext)
		let normalizedCount = DungeonMasterTurnValidation.normalizedOptions(from: draft.options).count
		if normalizedCount < DungeonMasterTurnValidation.minimumOptionCount {
			var properties: [String: Any] = [
				"option_count_before": normalizedCount,
			]
			if let sessionID = analyticsContext?.sessionID {
				properties["game_session_id"] = sessionID
			}
			if let turnID = analyticsContext?.turnID {
				properties["turn_id"] = turnID
			}
			AppAnalytics.capture("dm_turn_invalid_options", properties: properties)
		}
		return draft.resolved()
	}

	func illustrate(
		visualPrompt: String,
		analyticsContext: AIAnalyticsContext? = nil
	) async throws -> SceneImage {
		let trimmed = visualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { throw SceneMediaError.emptyPrompt }

		var properties: [String: Any] = [
			"prompt_length": trimmed.count,
		]
		if let sessionID = analyticsContext?.sessionID {
			properties["game_session_id"] = sessionID
		}
		if let turnID = analyticsContext?.turnID {
			properties["turn_id"] = turnID
		}
		AppAnalytics.capture("vision_scene_generate_started", properties: properties)

		do {
			let cgImage = try await illustrator.illustrate(trimmed)
			AppAnalytics.capture("vision_scene_generate_succeeded", properties: properties)
			return SceneImage(cgImage: cgImage)
		} catch {
			properties["error_type"] = String(describing: type(of: error))
			AppAnalytics.capture("vision_scene_generate_failed", properties: properties)
			throw error
		}
	}

	static func defaultNarrator() -> any DungeonNarrator {
		#if DEBUG
			if ScriptedNarrator.isEnabledByDefaults {
				return ScriptedNarrator.demo()
			}
		#endif
		return PrivateCloudNarrator()
	}
}

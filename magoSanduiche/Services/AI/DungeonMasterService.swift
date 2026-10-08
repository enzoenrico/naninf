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
		self.illustrator = illustrator ?? DreamLiteIllustrator()
	}

	var illustratesWithSystemSheet: Bool {
		illustrator.illustratesWithSystemSheet
	}

	func generate(
		context: DungeonMasterTurnContext,
		analyticsContext: AIAnalyticsContext? = nil
	) async throws(DungeonMasterError) -> DungeonMasterTurn {
		let prompt = DungeonMasterTurnFormatter.format(context)
		logUserPrompt(prompt, context: context, analyticsContext: analyticsContext)

		let draft: DungeonTurnDraft
		do {
			draft = try await narrator.draft(for: prompt, analyticsContext: analyticsContext)
		} catch let error where error == .refused {
			let shortened = context.keepingRecentStory()
			let retryPrompt = DungeonMasterTurnFormatter.format(shortened)
			guard retryPrompt != prompt else {
				logAIFailure(error, prompt: prompt, context: context, analyticsContext: analyticsContext)
				throw error
			}
			captureRefusalRetry(context: shortened, analyticsContext: analyticsContext)
			do {
				draft = try await narrator.draft(for: retryPrompt, analyticsContext: analyticsContext)
			} catch {
				logAIFailure(error, prompt: retryPrompt, context: shortened, analyticsContext: analyticsContext)
				throw error
			}
		} catch {
			logAIFailure(error, prompt: prompt, context: context, analyticsContext: analyticsContext)
			throw error
		}

		logAIResponse(draft, context: context, analyticsContext: analyticsContext)
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
		analyticsContext: AIAnalyticsContext? = nil,
		progress: SceneIllustrationProgress = .ignored
	) async throws -> SceneImage {
		let trimmed = visualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			AppAnalytics.log(
				"image_generation_prompt",
				level: .warn,
				attributes: imagePromptProperties(
					prompt: "",
					analyticsContext: analyticsContext,
					extra: ["error_kind": SceneMediaError.emptyPrompt.analyticsKind]
				)
			)
			throw SceneMediaError.emptyPrompt
		}

		var properties = imageEventProperties(trimmed, analyticsContext: analyticsContext)
		AppAnalytics.log(
			"image_generation_prompt",
			attributes: imagePromptProperties(prompt: trimmed, analyticsContext: analyticsContext)
		)
		AppAnalytics.capture("vision_scene_generate_started", properties: properties)

		do {
			let cgImage = try await illustrator.illustrate(trimmed, progress: progress)
			AppAnalytics.capture("vision_scene_generate_succeeded", properties: properties)
			return SceneImage(cgImage: SceneFrame.widescreen(cgImage))
		} catch {
			properties["error_kind"] = visionErrorKind(error)
			properties["error_detail"] = AppAnalytics.clipped(error.localizedDescription)
			AppAnalytics.capture("vision_scene_generate_failed", properties: properties)
			throw error
		}
	}

	private func captureRefusalRetry(
		context: DungeonMasterTurnContext,
		analyticsContext: AIAnalyticsContext?
	) {
		var properties: [String: Any] = [
			"turn_kind": context.kind.rawValue,
		]
		if let sessionID = analyticsContext?.sessionID {
			properties["game_session_id"] = sessionID
		}
		if let turnID = analyticsContext?.turnID {
			properties["turn_id"] = turnID
		}
		AppAnalytics.capture("dm_turn_refusal_retried", properties: properties)
	}

	private func logUserPrompt(
		_ prompt: String,
		context: DungeonMasterTurnContext,
		analyticsContext: AIAnalyticsContext?
	) {
		var attributes = turnProperties(context, analyticsContext: analyticsContext)
		attributes["player_message"] = context.playerMessage
		attributes["prompt"] = prompt
		attributes["prompt_length"] = prompt.count
		AppAnalytics.log("user_prompt", attributes: attributes)
	}

	private func logAIResponse(
		_ draft: DungeonTurnDraft,
		context: DungeonMasterTurnContext,
		analyticsContext: AIAnalyticsContext?
	) {
		var attributes = turnProperties(context, analyticsContext: analyticsContext)
		attributes["narrative"] = draft.narrative
		attributes["narrative_length"] = draft.narrative.count
		attributes["options"] = draft.options.joined(separator: "\n")
		attributes["option_count"] = draft.options.count
		attributes["visual_prompt"] = draft.scene.poseOrAction
		attributes["visual_prompt_length"] = draft.scene.poseOrAction.count
		attributes["scene_location"] = draft.scene.location
		attributes["scene_move"] = draft.scene.move
		attributes["health_change"] = draft.healthChange
		attributes["mana_change"] = draft.manaChange
		attributes["next_input"] = nextInputName(draft.nextInput)
		AppAnalytics.log("ai_response", attributes: attributes)
	}

	private func logAIFailure(
		_ error: DungeonMasterError,
		prompt: String,
		context: DungeonMasterTurnContext,
		analyticsContext: AIAnalyticsContext?
	) {
		var attributes = turnProperties(context, analyticsContext: analyticsContext)
		attributes["prompt"] = prompt
		attributes["prompt_length"] = prompt.count
		attributes["error_kind"] = error.analyticsKind
		if let detail = error.analyticsDetail {
			attributes["error_detail"] = detail
		}
		let level: AppAnalytics.LogLevel = error.analyticsKind == "cancelled" ? .warn : .error
		AppAnalytics.log("ai_response", level: level, attributes: attributes)
	}

	private func turnProperties(
		_ context: DungeonMasterTurnContext,
		analyticsContext: AIAnalyticsContext?
	) -> [String: Any] {
		var properties: [String: Any] = [
			"turn_kind": context.kind.rawValue,
		]
		if let sessionID = analyticsContext?.sessionID {
			properties["game_session_id"] = sessionID
		}
		if let turnID = analyticsContext?.turnID {
			properties["turn_id"] = turnID
		}
		if let inputSource = analyticsContext?.inputSource {
			properties["input_source"] = inputSource
		}
		if let suggestionIndex = analyticsContext?.suggestionIndex {
			properties["suggestion_index"] = suggestionIndex
		}
		if let diceRoll = context.diceRoll {
			properties["dice_roll"] = diceRoll
		}
		return properties
	}

	private func nextInputName(_ nextInput: NextInput) -> String {
		switch nextInput {
		case .write:
			"write"
		case .roll:
			"roll"
		}
	}

	private func imageEventProperties(
		_ prompt: String,
		analyticsContext: AIAnalyticsContext?
	) -> [String: Any] {
		var properties: [String: Any] = [
			"prompt_length": prompt.count,
		]
		if let sessionID = analyticsContext?.sessionID {
			properties["game_session_id"] = sessionID
		}
		if let turnID = analyticsContext?.turnID {
			properties["turn_id"] = turnID
		}
		return properties
	}

	private func imagePromptProperties(
		prompt: String,
		analyticsContext: AIAnalyticsContext?,
		extra: [String: Any] = [:]
	) -> [String: Any] {
		var properties = imageEventProperties(prompt, analyticsContext: analyticsContext)
		properties["prompt"] = prompt
		properties["generator"] = "on_device"
		for (key, value) in extra {
			properties[key] = value
		}
		return properties
	}

	private func visionErrorKind(_ error: Error) -> String {
		if let sceneError = error as? SceneMediaError {
			return sceneError.analyticsKind
		}
		if let dreamLiteError = error as? DreamLiteError {
			return dreamLiteError.analyticsKind
		}
		let nsError = error as NSError
		if nsError.domain.isEmpty {
			return "illustrator"
		}
		return nsError.domain
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

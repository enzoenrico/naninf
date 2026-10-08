//
//  PrivateCloudNarrator.swift
//  magoSanduiche
//

import Foundation
import FoundationModels

struct PrivateCloudNarrator: DungeonNarrator {
	static let analyticsProvider = "apple_private_cloud_compute"
	static let analyticsModel = "private-cloud-compute"

	private let model: PrivateCloudComputeLanguageModel
	private let instructions: String

	init(
		model: PrivateCloudComputeLanguageModel = PrivateCloudComputeLanguageModel(),
		instructions: String = Prompts.systemPrompt
	) {
		self.model = model
		self.instructions = instructions
	}

	func draft(
		for prompt: String,
		analyticsContext: AIAnalyticsContext?
	) async throws(DungeonMasterError) -> DungeonTurnDraft {
		try preflight(analyticsContext: analyticsContext)
		let session = LanguageModelSession(model: model, instructions: instructions)
		let startedAt = Date()
		do {
			let response = try await session.respond(
				to: prompt,
				generating: DungeonTurnDraft.self,
				contextOptions: ContextOptions(includeSchemaInPrompt: true, reasoningLevel: .light)
			)
			captureGeneration(
				usage: response.usage,
				latency: Date().timeIntervalSince(startedAt),
				analyticsContext: analyticsContext,
				failure: nil
			)
			return response.content
		} catch {
			let failure = Self.mapped(error)
			captureGeneration(
				usage: nil,
				latency: Date().timeIntervalSince(startedAt),
				analyticsContext: analyticsContext,
				failure: failure
			)
			throw failure
		}
	}

	static func mapped(_ error: any Error) -> DungeonMasterError {
		if error is CancellationError {
			return .cancelled
		}
		if let cloudError = error as? PrivateCloudComputeLanguageModel.Error {
			switch cloudError {
			case .quotaLimitReached(let quota):
				return .quotaReached(resetDate: quota.resetDate)
			case .networkFailure, .serviceUnavailable:
				return .unreachable
			@unknown default:
				return .failed(cloudError.localizedDescription)
			}
		}
		if let modelError = error as? LanguageModelError {
			switch modelError {
			case .guardrailViolation, .refusal:
				return .refused
			case .rateLimited:
				return .unreachable
			case .contextSizeExceeded, .unsupportedCapability, .unsupportedTranscriptContent,
				.unsupportedGenerationGuide, .unsupportedLanguageOrLocale, .timeout:
				return .failed(modelError.localizedDescription)
			@unknown default:
				return .failed(modelError.localizedDescription)
			}
		}
		return .failed(error.localizedDescription)
	}

	private func preflight(analyticsContext: AIAnalyticsContext?) throws(DungeonMasterError) {
		switch model.availability {
		case .available:
			break
		case .unavailable(.deviceNotEligible):
			throw .unavailable(.deviceNotEligible)
		case .unavailable(.systemNotReady):
			throw .unavailable(.systemNotReady)
		@unknown default:
			throw .failed("Private Cloud Compute is unavailable.")
		}

		switch model.quotaUsage.status {
		case .limitReached:
			throw .quotaReached(resetDate: model.quotaUsage.resetDate)
		case .belowLimit(let below) where below.isApproachingLimit:
			var properties: [String: Any] = [:]
			if let sessionID = analyticsContext?.sessionID {
				properties["game_session_id"] = sessionID
			}
			if let turnID = analyticsContext?.turnID {
				properties["turn_id"] = turnID
			}
			AppAnalytics.capture("pcc_quota_approaching", properties: properties)
		case .belowLimit:
			break
		@unknown default:
			break
		}
	}

	private func captureGeneration(
		usage: LanguageModelSession.Usage?,
		latency: TimeInterval,
		analyticsContext: AIAnalyticsContext?,
		failure: DungeonMasterError?
	) {
		var properties: [String: Any] = [:]
		if let failure {
			properties["$ai_is_error"] = true
			properties["error_kind"] = failure.analyticsKind
		}
		AppAnalytics.captureAIGeneration(
			traceID: analyticsContext?.turnID ?? UUID().uuidString,
			sessionID: analyticsContext?.sessionID,
			spanID: UUID().uuidString,
			spanName: "dungeon_turn",
			model: Self.analyticsModel,
			inputTokens: usage?.input.totalTokenCount,
			outputTokens: usage?.output.totalTokenCount,
			reasoningTokens: usage?.output.reasoningTokenCount,
			totalTokens: usage?.totalTokenCount,
			latency: latency,
			properties: properties
		)
	}
}

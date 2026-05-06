//
//  AppAnalytics.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/05/26.
//

import Foundation
import PostHog

struct AIAnalyticsContext {
	let sessionID: String
	let turnID: String
}

enum AppAnalytics {
	private enum InfoKey {
		static let projectToken = "POSTHOG_PROJECT_TOKEN"
		static let host = "POSTHOG_HOST"
	}

	private enum StorageKey {
		static let anonymousPlayerID = "analyticsAnonymousPlayerID"
	}

	private static var isConfigured = false

	static var distinctID: String {
		anonymousPlayerID()
	}

	static func configure(bundle: Bundle = .main) {
		guard !isConfigured else { return }
		guard let projectToken = sanitizedString(for: InfoKey.projectToken, in: bundle) else { return }
		let host = sanitizedString(for: InfoKey.host, in: bundle) ?? "https://us.i.posthog.com"

		let config = PostHogConfig(projectToken: projectToken, host: host)
		config.captureApplicationLifecycleEvents = true
		#if DEBUG
			config.debug = true
		#endif
		PostHogSDK.shared.setup(config)
		isConfigured = true
		identifyAnonymousPlayer()
	}

	static func capture(_ event: String, properties: [String: Any] = [:]) {
		guard isConfigured else { return }
		PostHogSDK.shared.capture(event, properties: commonProperties().merging(properties) { _, new in new })
	}

	static func captureAIGeneration(
		traceID: String,
		sessionID: String?,
		spanID: String,
		spanName: String,
		model: String,
		input: Any,
		outputChoices: Any?,
		inputTokens: Int?,
		outputTokens: Int?,
		totalTokens: Int?,
		latency: TimeInterval,
		properties: [String: Any] = [:]
	) {
		var eventProperties = commonProperties().merging(properties) { _, new in new }
		eventProperties["$ai_trace_id"] = traceID
		eventProperties.setIfPresent(sessionID, forKey: "$ai_session_id")
		eventProperties["$ai_span_id"] = spanID
		eventProperties["$ai_span_name"] = spanName
		eventProperties["$ai_model"] = model
		eventProperties["$ai_provider"] = "openai"
		eventProperties["$ai_input"] = input
		eventProperties.setIfPresent(inputTokens, forKey: "$ai_input_tokens")
		eventProperties.setIfPresent(outputChoices, forKey: "$ai_output_choices")
		eventProperties.setIfPresent(outputTokens, forKey: "$ai_output_tokens")
		eventProperties.setIfPresent(totalTokens, forKey: "total_tokens")
		eventProperties["$ai_latency"] = latency
		eventProperties["$ai_stream"] = false
		eventProperties["distinct_id"] = distinctID

		capture("$ai_generation", properties: eventProperties)
	}

	static func captureAIError(
		traceID: String,
		sessionID: String?,
		spanID: String,
		spanName: String,
		model: String,
		input: Any,
		latency: TimeInterval,
		error: Error,
		properties: [String: Any] = [:]
	) {
		captureAIGeneration(
			traceID: traceID,
			sessionID: sessionID,
			spanID: spanID,
			spanName: spanName,
			model: model,
			input: input,
			outputChoices: nil,
			inputTokens: nil,
			outputTokens: nil,
			totalTokens: nil,
			latency: latency,
			properties: properties.merging([
				"$ai_is_error": true,
				"$ai_error": error.localizedDescription,
				"error_type": String(describing: type(of: error))
			]) { _, new in new }
		)
	}

	private static func identifyAnonymousPlayer() {
		PostHogSDK.shared.identify(distinctID, userProperties: [
			"user_type": "anonymous_player"
		])
	}

	private static func anonymousPlayerID() -> String {
		let defaults = UserDefaults.standard
		if let existing = defaults.string(forKey: StorageKey.anonymousPlayerID), !existing.isEmpty {
			return existing
		}

		let created = UUID().uuidString
		defaults.set(created, forKey: StorageKey.anonymousPlayerID)
		return created
	}

	private static func sanitizedString(for key: String, in bundle: Bundle) -> String? {
		guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		guard !trimmed.hasPrefix("$(") else { return nil }
		return trimmed
	}

	private static func commonProperties() -> [String: Any] {
		[
			"distinct_id": distinctID,
			"app_platform": "ios",
			"app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
			"app_build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
		]
	}
}

private extension Dictionary where Key == String, Value == Any {
	mutating func setIfPresent(_ value: Any?, forKey key: String) {
		guard let value else { return }
		self[key] = value
	}
}

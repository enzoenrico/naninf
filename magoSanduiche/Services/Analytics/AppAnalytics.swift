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

	private static var isConfigured = false

	static func configure(bundle: Bundle = .main) {
		guard !isConfigured else { return }
		guard let projectToken = sanitizedString(for: InfoKey.projectToken, in: bundle) else { return }
		let host = sanitizedString(for: InfoKey.host, in: bundle) ?? "https://us.i.posthog.com"

		let config = PostHogConfig(projectToken: projectToken, host: host)
		config.captureApplicationLifecycleEvents = true
		// SwiftUI screen autocapture records hosting-controller type names, which cannot be used as screens.
		config.captureScreenViews = false
		// Onboarding drop-off happens before sign-in, so anonymous players still need person profiles.
		config.personProfiles = .always
		#if DEBUG
			config.debug = true
		#endif
		PostHogSDK.shared.setup(config)
		isConfigured = true
	}

	static func capture(_ event: String, properties: [String: Any] = [:]) {
		guard shouldCapture else { return }
		PostHogSDK.shared.capture(event, properties: commonProperties().merging(properties) { _, new in new })
	}

	static func screen(_ name: String, properties: [String: Any] = [:]) {
		guard shouldCapture else { return }
		PostHogSDK.shared.screen(name, properties: commonProperties().merging(properties) { _, new in new })
	}

	/// Links this device's anonymous activity to the signed-in player.
	/// Earlier builds called `identify` with a local UUID, which blocks a later identify. Only that stuck state resets.
	static func identifySignedInPlayer(userID: String, provider: String) {
		guard shouldCapture else { return }
		guard !userID.isEmpty else { return }
		let properties: [String: Any] = [
			"user_type": "player",
			"auth_provider": provider,
			"signed_in": true,
		]
		if PostHogSDK.shared.getDistinctId() == userID {
			PostHogSDK.shared.identify(userID, userProperties: properties)
			return
		}
		PostHogSDK.shared.identify(userID, userProperties: properties)
		if PostHogSDK.shared.getDistinctId() == userID {
			return
		}
		PostHogSDK.shared.reset()
		PostHogSDK.shared.identify(userID, userProperties: properties)
	}

	static func markSignedOut() {
		guard shouldCapture else { return }
		PostHogSDK.shared.setPersonProperties(userPropertiesToSet: ["signed_in": false])
		PostHogSDK.shared.reset()
	}

	static func setPersonProperties(_ properties: [String: Any]) {
		guard shouldCapture else { return }
		guard !properties.isEmpty else { return }
		PostHogSDK.shared.setPersonProperties(userPropertiesToSet: properties)
	}

	static func clipped(_ text: String, limit: Int = 160) -> String {
		guard text.count > limit else { return text }
		return String(text.prefix(limit))
	}

	static func captureAIGeneration(
		traceID: String,
		sessionID: String?,
		spanID: String,
		spanName: String,
		model: String,
		inputTokens: Int?,
		outputTokens: Int?,
		reasoningTokens: Int?,
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
		eventProperties["$ai_provider"] = PrivateCloudNarrator.analyticsProvider
		eventProperties.setIfPresent(inputTokens, forKey: "$ai_input_tokens")
		eventProperties.setIfPresent(outputTokens, forKey: "$ai_output_tokens")
		eventProperties.setIfPresent(reasoningTokens, forKey: "$ai_reasoning_tokens")
		eventProperties.setIfPresent(totalTokens, forKey: "total_tokens")
		eventProperties["$ai_latency"] = latency
		eventProperties["$ai_stream"] = false

		capture("$ai_generation", properties: eventProperties)
	}

	private static var shouldCapture: Bool {
		guard isConfigured else { return false }
		return !UITestConfiguration.isActive
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

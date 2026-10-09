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
    var inputSource: String? = nil
    var suggestionIndex: Int? = nil
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

        config.logs.serviceName = "nanInf-logs"
        #if DEBUG
            config.debug = true
            config.logs.environment = "debug"
        #else
            config.logs.environment = "production"
        #endif
        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    enum LogLevel {
        case trace
        case debug
        case info
        case warn
        case error
        case fatal

        fileprivate var severity: PostHogLogSeverity {
            switch self {
            case .trace: .trace
            case .debug: .debug
            case .info: .info
            case .warn: .warn
            case .error: .error
            case .fatal: .fatal
            }
        }
    }

    static func capture(_ event: String, properties: [String: Any] = [:]) {
        guard shouldCapture else { return }
        let merged = commonProperties().merging(properties) { _, new in new }
        PostHogSDK.shared.capture(event, properties: merged)
        var logAttributes = merged
        logAttributes["log_category"] = category(for: event)
        emitLog(event, level: severity(for: event), attributes: logAttributes)
    }

    static func screen(_ name: String, properties: [String: Any] = [:]) {
        guard shouldCapture else { return }
        let merged = commonProperties().merging(properties) { _, new in new }
        PostHogSDK.shared.screen(name, properties: merged)
        var logAttributes = merged
        logAttributes["log_category"] = "user_action"
        logAttributes["screen_name"] = name
        emitLog("screen:\(name)", level: .info, attributes: logAttributes)
    }

    /// Structured Logs record. User actions are also written from `capture` and `screen`.
    /// AI feedback (prompts and model output) should pass the full text in `attributes`.
    static func log(
        _ message: String,
        level: LogLevel = .info,
        attributes: [String: Any] = [:]
    ) {
        guard shouldCapture else { return }
        var merged = commonProperties().merging(attributes) { _, new in new }
        if merged["log_category"] == nil {
            merged["log_category"] = "ai_feedback"
        }
        emitLog(message, level: level, attributes: merged)
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

    private static func emitLog(_ message: String, level: LogLevel, attributes: [String: Any]) {
        let body = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        PostHogSDK.shared.captureLog(body, level: level.severity, attributes: attributes)
    }

    private static func severity(for event: String) -> LogLevel {
        let name = event.lowercased()
        if name.contains("failed") || name.contains("error") || name.contains("defeated") {
            return .error
        }
        if name.contains("invalid") || name.contains("approaching") || name.contains("empty") {
            return .warn
        }
        return .info
    }

    private static func category(for event: String) -> String {
        if event.hasPrefix("$ai_")
            || event.hasPrefix("dm_")
            || event.hasPrefix("vision_")
            || event.hasPrefix("pcc_")
        {
            return "ai_feedback"
        }
        return "user_action"
    }

    private static var shouldCapture: Bool {
        guard isConfigured else { return false }
        #if DEBUG
            return !UITestConfiguration.isActive
        #else
            return true
        #endif
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
            "app_build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
        ]
    }
}

private extension Dictionary where Key == String, Value == Any {
    mutating func setIfPresent(_ value: Any?, forKey key: String) {
        guard let value else { return }
        self[key] = value
    }
}

//
//  GameViewModel+Analytics.swift
//  magoSanduiche
//

import Foundation

extension GameViewModel {
    var sessionAnalyticsProperties: [String: Any] {
        [
            "game_session_id": gameSessionID,
            "health": health,
            "mana": mana,
            "max_health": maxHealth,
            "max_mana": maxMana,
        ]
    }

    func aiContext(
        turnID: String,
        inputSource: String? = nil,
        suggestionIndex: Int? = nil
    ) -> AIAnalyticsContext {
        AIAnalyticsContext(
            sessionID: gameSessionID,
            turnID: turnID,
            inputSource: inputSource,
            suggestionIndex: suggestionIndex
        )
    }

    func capture(_ event: String, extra: [String: Any] = [:]) {
        var properties = sessionAnalyticsProperties
        for (key, value) in extra {
            properties[key] = value
        }
        AppAnalytics.capture(event, properties: properties)
    }

    func log(
        _ message: String,
        level: AppAnalytics.LogLevel = .info,
        extra: [String: Any] = [:]
    ) {
        var properties = sessionAnalyticsProperties
        for (key, value) in extra {
            properties[key] = value
        }
        AppAnalytics.log(message, level: level, attributes: properties)
    }

    func incrementStoredCounter(_ key: String) {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }
}

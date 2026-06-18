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

    func aiContext(turnID: String) -> AIAnalyticsContext {
        AIAnalyticsContext(sessionID: gameSessionID, turnID: turnID)
    }

    func capture(_ event: String, extra: [String: Any] = [:]) {
        var properties = sessionAnalyticsProperties
        for (key, value) in extra {
            properties[key] = value
        }
        AppAnalytics.capture(event, properties: properties)
    }
}

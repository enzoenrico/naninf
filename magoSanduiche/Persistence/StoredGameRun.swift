//
//  StoredGameRun.swift
//  magoSanduiche
//

import Foundation
import SwiftData

@Model
final class StoredGameRun {
	@Attribute(.unique) var id: UUID
	var createdAt: Date
	var updatedAt: Date
	var displayTitle: String
	var transcriptBlob: Data
	var health: Int
	var mana: Int
	var maxHealth: Int
	var maxMana: Int
	var diceValue: Int
	var pendingDiceRoll: Int?
	var diceRevealStageRaw: String
	var diceResultText: String
	var invalidInputAttempts: Int
	var contextualInput: String
	var contextActionRaw: String
	var uiPhaseRaw: String
	var suggestedOptionsBlob: Data
	var suppressTerminalAnimations: Bool
	var isEphemeralTutorial: Bool
	var schemaVersion: Int
	var analyticsSessionID: String
	var aiHistoryBlob: Data?
	var previewImageRelativePath: String?

	init(
		id: UUID,
		createdAt: Date,
		updatedAt: Date,
		displayTitle: String,
		transcriptBlob: Data,
		health: Int,
		mana: Int,
		maxHealth: Int,
		maxMana: Int,
		diceValue: Int,
		pendingDiceRoll: Int?,
		diceRevealStageRaw: String,
		diceResultText: String,
		invalidInputAttempts: Int,
		contextualInput: String,
		contextActionRaw: String,
		uiPhaseRaw: String,
		suggestedOptionsBlob: Data,
		suppressTerminalAnimations: Bool,
		isEphemeralTutorial: Bool,
		schemaVersion: Int,
		analyticsSessionID: String,
		aiHistoryBlob: Data? = nil,
		previewImageRelativePath: String? = nil
	) {
		self.id = id
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.displayTitle = displayTitle
		self.transcriptBlob = transcriptBlob
		self.health = health
		self.mana = mana
		self.maxHealth = maxHealth
		self.maxMana = maxMana
		self.diceValue = diceValue
		self.pendingDiceRoll = pendingDiceRoll
		self.diceRevealStageRaw = diceRevealStageRaw
		self.diceResultText = diceResultText
		self.invalidInputAttempts = invalidInputAttempts
		self.contextualInput = contextualInput
		self.contextActionRaw = contextActionRaw
		self.uiPhaseRaw = uiPhaseRaw
		self.suggestedOptionsBlob = suggestedOptionsBlob
		self.suppressTerminalAnimations = suppressTerminalAnimations
		self.isEphemeralTutorial = isEphemeralTutorial
		self.schemaVersion = schemaVersion
		self.analyticsSessionID = analyticsSessionID
		self.aiHistoryBlob = aiHistoryBlob
		self.previewImageRelativePath = previewImageRelativePath
	}
}

enum GameRunPersistSchema {
	static let currentVersion = 1
}

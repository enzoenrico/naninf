//
//  GameRunSnapshotMapper.swift
//  magoSanduiche
//

import Foundation
import SwiftData

struct GameRunSnapshotFields {
	let transcriptBlob: Data
	let suggestedOptionsBlob: Data
	let displayTitle: String
	let health: Int
	let mana: Int
	let maxHealth: Int
	let maxMana: Int
	let diceValue: Int
	let pendingDiceRoll: Int?
	let diceRevealStageRaw: String
	let diceResultText: String
	let invalidInputAttempts: Int
	let contextualInput: String
	let contextActionRaw: String
	let uiPhaseRaw: String
	let suppressTerminalAnimations: Bool
}

enum GameRunSnapshotMapper {
	struct LiveState {
		let terminalEntries: [TerminalEntry]
		let suggestedOptions: [String]
		let health: Int
		let mana: Int
		let maxHealth: Int
		let maxMana: Int
		let diceValue: Int
		let pendingDiceRoll: Int?
		let diceRevealStage: DiceRevealStage
		let diceResultText: String
		let invalidInputAttempts: Int
		let contextualInput: String
		let contextAction: GameAction
		let uiPhase: GameUIPhase
		let suppressTerminalAnimations: Bool
	}

	struct PlaybackState {
		let terminalEntries: [TerminalEntry]
		let health: Int
		let mana: Int
		let maxHealth: Int
		let maxMana: Int
		let diceValue: Int
		let pendingDiceRoll: Int?
		let diceRevealStage: DiceRevealStage
		let diceResultText: String
		let invalidInputAttempts: Int
		let contextualInput: String
		let contextAction: GameAction
		let uiPhase: GameUIPhase
		let suggestedOptions: [String]
		let suppressTerminalAnimations: Bool
	}

	static let defaultTerminalEntries: [TerminalEntry] = [
		TerminalEntry(kind: .dungeonMaster, text: Introduction.intro),
	]

	static let jsonEncoder: JSONEncoder = {
		let e = JSONEncoder()
		e.outputFormatting = [.sortedKeys]
		return e
	}()

	static let jsonDecoder = JSONDecoder()

	static func persistedLines(from entries: [TerminalEntry]) -> [PersistedTerminalLine] {
		entries.map {
			PersistedTerminalLine(id: $0.id, kind: .init(from: $0.kind), text: $0.text)
		}
	}

	static func encodeSuggestedOptions(_ options: [String]) throws -> Data {
		try jsonEncoder.encode(options)
	}

	static func decodeSuggestedOptions(from data: Data) -> [String] {
		(try? jsonDecoder.decode([String].self, from: data)) ?? []
	}

	static func encodeTranscript(_ lines: [PersistedTerminalLine]) throws -> Data {
		try jsonEncoder.encode(lines)
	}

	static func decodeTranscript(from data: Data) throws -> [PersistedTerminalLine] {
		try jsonDecoder.decode([PersistedTerminalLine].self, from: data)
	}

	static func terminalEntries(from transcriptBlob: Data) -> [TerminalEntry] {
		do {
			let lines = try decodeTranscript(from: transcriptBlob)
			guard !lines.isEmpty else { return defaultTerminalEntries }
			return lines.map {
				TerminalEntry(id: $0.id, kind: $0.kind.terminalKind, text: $0.text)
			}
		} catch {
			return defaultTerminalEntries
		}
	}

	static func apply(
		_ fields: GameRunSnapshotFields,
		to run: StoredGameRun,
		updatedAt: Date,
		analyticsSessionID: String
	) {
		run.updatedAt = updatedAt
		run.displayTitle = fields.displayTitle
		run.transcriptBlob = fields.transcriptBlob
		run.health = fields.health
		run.mana = fields.mana
		run.maxHealth = fields.maxHealth
		run.maxMana = fields.maxMana
		run.diceValue = fields.diceValue
		run.pendingDiceRoll = fields.pendingDiceRoll
		run.diceRevealStageRaw = fields.diceRevealStageRaw
		run.diceResultText = fields.diceResultText
		run.invalidInputAttempts = fields.invalidInputAttempts
		run.contextualInput = fields.contextualInput
		run.contextActionRaw = fields.contextActionRaw
		run.uiPhaseRaw = fields.uiPhaseRaw
		run.suggestedOptionsBlob = fields.suggestedOptionsBlob
		run.suppressTerminalAnimations = fields.suppressTerminalAnimations
		run.schemaVersion = GameRunPersistSchema.currentVersion
		run.analyticsSessionID = analyticsSessionID
	}

	static func makeStoredGameRun(
		id: UUID,
		createdAt: Date,
		updatedAt: Date,
		fields: GameRunSnapshotFields,
		analyticsSessionID: String
	) -> StoredGameRun {
		StoredGameRun(
			id: id,
			createdAt: createdAt,
			updatedAt: updatedAt,
			displayTitle: fields.displayTitle,
			transcriptBlob: fields.transcriptBlob,
			health: fields.health,
			mana: fields.mana,
			maxHealth: fields.maxHealth,
			maxMana: fields.maxMana,
			diceValue: fields.diceValue,
			pendingDiceRoll: fields.pendingDiceRoll,
			diceRevealStageRaw: fields.diceRevealStageRaw,
			diceResultText: fields.diceResultText,
			invalidInputAttempts: fields.invalidInputAttempts,
			contextualInput: fields.contextualInput,
			contextActionRaw: fields.contextActionRaw,
			uiPhaseRaw: fields.uiPhaseRaw,
			suggestedOptionsBlob: fields.suggestedOptionsBlob,
			suppressTerminalAnimations: fields.suppressTerminalAnimations,
			isEphemeralTutorial: false,
			schemaVersion: GameRunPersistSchema.currentVersion,
			analyticsSessionID: analyticsSessionID
		)
	}

	static func displayTitle(entries: [TerminalEntry], fallback: Date = Date()) -> String {
		if let snippet = entries.first(where: { $0.kind == .player })?.text.trimmingCharacters(in: .whitespacesAndNewlines),
			!snippet.isEmpty
		{
			let maxLen = 48
			if snippet.count <= maxLen { return snippet }
			return String(snippet.prefix(maxLen - 1)) + "…"
		}
		let fmt = DateFormatter()
		fmt.dateStyle = .medium
		fmt.timeStyle = .short
		let dateStr = fmt.string(from: fallback)
		return String(format: String(localized: "nan_load_run_title_fallback_format"), locale: .current, dateStr)
	}

	// MARK: - Raw string bridges

	static func contextActionRaw(_ action: GameAction) -> String {
		switch action {
		case .write: return "write"
		case .roll: return "roll"
		}
	}

	static func contextAction(from raw: String) -> GameAction {
		raw == "roll" ? .roll : .write
	}

	static func uiPhaseRaw(_ phase: GameUIPhase) -> String {
		switch phase {
		case .reading: return "reading"
		case .ready: return "ready"
		case .composing: return "composing"
		case .awaitingDungeonMaster: return "awaitingDungeonMaster"
		case .rollingDice: return "rollingDice"
		case .result: return "result"
		}
	}

	static func uiPhase(from raw: String) -> GameUIPhase {
		switch raw {
		case "ready": return .ready
		case "composing": return .composing
		case "awaitingDungeonMaster": return .awaitingDungeonMaster
		case "rollingDice": return .rollingDice
		case "result": return .result
		default: return .reading
		}
	}

	static func diceRevealStageRaw(_ stage: DiceRevealStage) -> String {
		switch stage {
		case .idle: return "idle"
		case .scrambling: return "scrambling"
		case .fadingOut: return "fadingOut"
		case .suspense: return "suspense"
		case .bamReveal: return "bamReveal"
		}
	}

	static func diceRevealStage(from raw: String) -> DiceRevealStage {
		switch raw {
		case "scrambling": return .scrambling
		case "fadingOut": return .fadingOut
		case "suspense": return .suspense
		case "bamReveal": return .bamReveal
		default: return .idle
		}
	}

	// MARK: - Fetch

	static func fetch(id: UUID, context: ModelContext) -> StoredGameRun? {
		let desc = FetchDescriptor<StoredGameRun>(predicate: #Predicate { $0.id == id })
		return try? context.fetch(desc).first
	}

	static func playbackState(from stored: StoredGameRun) -> PlaybackState {
		PlaybackState(
			terminalEntries: terminalEntries(from: stored.transcriptBlob),
			health: stored.health,
			mana: stored.mana,
			maxHealth: stored.maxHealth,
			maxMana: stored.maxMana,
			diceValue: stored.diceValue,
			pendingDiceRoll: stored.pendingDiceRoll,
			diceRevealStage: diceRevealStage(from: stored.diceRevealStageRaw),
			diceResultText: stored.diceResultText,
			invalidInputAttempts: stored.invalidInputAttempts,
			contextualInput: stored.contextualInput,
			contextAction: contextAction(from: stored.contextActionRaw),
			uiPhase: uiPhase(from: stored.uiPhaseRaw),
			suggestedOptions: decodeSuggestedOptions(from: stored.suggestedOptionsBlob),
			suppressTerminalAnimations: stored.suppressTerminalAnimations
		)
	}

	static func snapshotFields(from state: LiveState, createdAt: Date) throws -> GameRunSnapshotFields {
		let persistedLines = persistedLines(from: state.terminalEntries)
		let transcriptBlob = try encodeTranscript(persistedLines)
		let suggestedBlob = try encodeSuggestedOptions(state.suggestedOptions)
		return GameRunSnapshotFields(
			transcriptBlob: transcriptBlob,
			suggestedOptionsBlob: suggestedBlob,
			displayTitle: displayTitle(entries: state.terminalEntries, fallback: createdAt),
			health: state.health,
			mana: state.mana,
			maxHealth: state.maxHealth,
			maxMana: state.maxMana,
			diceValue: state.diceValue,
			pendingDiceRoll: state.pendingDiceRoll,
			diceRevealStageRaw: diceRevealStageRaw(state.diceRevealStage),
			diceResultText: state.diceResultText,
			invalidInputAttempts: state.invalidInputAttempts,
			contextualInput: state.contextualInput,
			contextActionRaw: contextActionRaw(state.contextAction),
			uiPhaseRaw: uiPhaseRaw(state.uiPhase),
			suppressTerminalAnimations: state.suppressTerminalAnimations
		)
	}
}

//
//  GameRunSnapshotMapper.swift
//  magoSanduiche
//

import Foundation
import SwiftData

enum GameRunSnapshotMapper {
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
}

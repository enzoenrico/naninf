//
//  PersistedGameRunCoding.swift
//  magoSanduiche
//

import Foundation

enum PersistedTerminalEntryKind: String, Codable, CaseIterable {
	case dungeonMaster
	case player
	case dice
	case system

	init(from kind: TerminalEntryKind) {
		switch kind {
		case .dungeonMaster: self = .dungeonMaster
		case .player: self = .player
		case .dice: self = .dice
		case .system: self = .system
		}
	}

	var terminalKind: TerminalEntryKind {
		switch self {
		case .dungeonMaster: .dungeonMaster
		case .player: .player
		case .dice: .dice
		case .system: .system
		}
	}
}

struct PersistedTerminalLine: Codable, Equatable {
	var id: UUID
	var kind: PersistedTerminalEntryKind
	var text: String
}

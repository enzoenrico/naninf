//
//  TerminalEntry.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.
//

import Foundation

enum TerminalEntryKind: Sendable {
	case dungeonMaster
	case player
	case dice
	case system

	var prefix: String {
		switch self {
		case .dungeonMaster:
			String(localized: "nan_terminal_prefix_dm")
		case .player:
			String(localized: "nan_terminal_prefix_you")
		case .dice:
			String(localized: "nan_terminal_prefix_d20")
		case .system:
			String(localized: "nan_terminal_prefix_sys")
		}
	}
}

struct TerminalEntry: Identifiable, Sendable {
	let id: UUID
	let kind: TerminalEntryKind
	let text: String

	init(id: UUID = UUID(), kind: TerminalEntryKind, text: String) {
		self.id = id
		self.kind = kind
		self.text = text
	}

	var renderedText: String {
		"\(kind.prefix)\n\(text)"
	}
}

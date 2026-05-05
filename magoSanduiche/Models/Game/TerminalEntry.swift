//
//  TerminalEntry.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 06/12/25.
//

import Foundation

enum TerminalEntryKind {
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

struct TerminalEntry: Identifiable {
	let id = UUID()
	let kind: TerminalEntryKind
	let text: String

	var renderedText: String {
		"\(kind.prefix)\n\(text)"
	}
}

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
			"> DM"
		case .player:
			"> YOU"
		case .dice:
			"> D20"
		case .system:
			"> SYS"
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

//
//  PlayerPromptID.swift
//  magoSanduiche
//

import Foundation

nonisolated struct PlayerPromptID: Hashable, Sendable {
	let entryID: UUID

	init?(_ entry: TerminalEntry) {
		guard entry.kind == .player else { return nil }
		entryID = entry.id
	}
}

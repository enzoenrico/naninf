//
//  DungeonMasterTurnFormatterTests.swift
//  magoSanduicheTests
//

import Testing
@testable import magoSanduiche

struct DungeonMasterTurnFormatterTests {
	@Test func playerTextTurnIncludesMessageAndState() {
		let formatted = DungeonMasterTurnFormatter.format(
			.fixture(
				playerMessage: "I search the room",
				storySoFar: [TerminalEntry(kind: .dungeonMaster, text: "> Torches flicker.")]
			)
		)

		#expect(formatted.contains("turnKind: playerText"))
		#expect(formatted.contains("playerMessage: I search the room"))
		#expect(formatted.contains("health: 10/18"))
		#expect(formatted.contains("DM: > Torches flicker."))
	}

	@Test func diceConfirmationTurnSuppliesTheRollForThePreviousNarration() {
		let formatted = DungeonMasterTurnFormatter.format(
			.fixture(
				kind: .diceResultConfirmation,
				storySoFar: [
					TerminalEntry(kind: .player, text: "I force the gate"),
					TerminalEntry(kind: .dungeonMaster, text: "> The gate holds.\nRoll to force it."),
				],
				diceRoll: 17
			)
		)

		#expect(formatted.contains("turnKind: diceResultConfirmation"))
		#expect(formatted.contains("playerD20Roll: 17"))
		#expect(formatted.contains("pendingCheck: > The gate holds. Roll to force it."))
		#expect(!formatted.contains("instruction:"))
		#expect(!formatted.contains("playerMessage:"))
	}

	@Test func storySoFarKeepsNewestEntriesWithinBudget() {
		let entries = (0..<500).map { index in
			TerminalEntry(
				kind: .dungeonMaster,
				text: "> beat \(index) " + String(repeating: "x", count: 40)
			)
		}
		let formatted = DungeonMasterTurnFormatter.format(.fixture(storySoFar: entries))

		#expect(formatted.contains("> beat 499"))
		#expect(!formatted.contains("> beat 0\n"))
		#expect(formatted.count <= DungeonMasterTurnFormatter.storyCharacterBudget + 1_000)
	}
}

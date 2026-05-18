//
//  DungeonMasterTurnFormatterTests.swift
//  magoSanduicheTests
//

import Testing
@testable import magoSanduiche

struct DungeonMasterTurnFormatterTests {
	@Test func playerTextTurnIncludesMessageAndState() {
		let formatted = DungeonMasterTurnFormatter.format(
			DungeonMasterTurnContext(
				kind: .playerText,
				playerMessage: "I search the room",
				health: 10,
				maxHealth: 18,
				mana: 14,
				maxMana: 18,
				latestDungeonMasterExcerpt: "> Torches flicker.",
				diceRoll: nil,
				diceOutcomeSummary: nil
			)
		)

		#expect(formatted.contains("turnKind: playerText"))
		#expect(formatted.contains("playerMessage: I search the room"))
		#expect(formatted.contains("health: 10/18"))
		#expect(formatted.contains("latestDungeonMasterExcerpt:"))
	}

	@Test func diceConfirmationTurnIncludesRoll() {
		let formatted = DungeonMasterTurnFormatter.format(
			DungeonMasterTurnContext(
				kind: .diceResultConfirmation,
				playerMessage: "",
				health: 8,
				maxHealth: 18,
				mana: 14,
				maxMana: 18,
				latestDungeonMasterExcerpt: nil,
				diceRoll: 17,
				diceOutcomeSummary: "A bright 17. Arcane luck surges."
			)
		)

		#expect(formatted.contains("turnKind: diceResultConfirmation"))
		#expect(formatted.contains("playerD20Roll: 17"))
		#expect(formatted.contains("rollOutcomeSummary:"))
		#expect(formatted.contains("decideAction"))
	}
}

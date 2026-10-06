//
//  DungeonTurnDraftTests.swift
//  magoSanduicheTests
//

import Testing
@testable import magoSanduiche

struct DungeonTurnDraftTests {
	@Test func resolvedOrdersEffectsHealthManaThenAction() {
		let turn = DungeonTurnDraft(
			narrative: "> Hit",
			healthChange: -6,
			manaChange: -2,
			nextInput: .roll,
			options: ["A", "B", "C"],
			visualPrompt: ""
		).resolved()

		#expect(turn.toolEffects == [.changeHealth(-6), .changeMana(-2), .requestAction(.roll)])
	}

	@Test func resolvedOmitsZeroDeltasButAlwaysRequestsAction() {
		let turn = DungeonTurnDraft(
			narrative: "> Calm",
			healthChange: 0,
			manaChange: 0,
			nextInput: .write,
			options: ["A", "B", "C"],
			visualPrompt: "  "
		).resolved()

		#expect(turn.toolEffects == [.requestAction(.write)])
		#expect(turn.output.visualPrompt == nil)
	}

	@Test func resolvedClampsOutOfRangeDeltas() {
		let turn = DungeonTurnDraft(
			narrative: "> Boom",
			healthChange: -999,
			manaChange: 999,
			nextInput: .write,
			options: [],
			visualPrompt: ""
		).resolved()

		#expect(turn.toolEffects == [.changeHealth(-40), .changeMana(30), .requestAction(.write)])
		#expect(turn.output.options.count == 3)
	}

	@Test func resolvedPadsShortOptionLists() {
		let turn = DungeonTurnDraft(
			narrative: "> Narrow",
			healthChange: 0,
			manaChange: 0,
			nextInput: .write,
			options: ["Run", " ", ""],
			visualPrompt: ""
		).resolved()

		#expect(turn.output.options.count == 3)
		#expect(turn.output.options[0] == "Run")
		#expect(turn.output.visualPrompt == nil)
	}
}

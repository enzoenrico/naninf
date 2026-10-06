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

@MainActor
struct GameViewModelManaTests {
	private func makeViewModel() -> GameViewModel {
		GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(narrator: ScriptedNarrator(drafts: []))
		)
	}

	@Test func changeManaClampsBetweenZeroAndMax() {
		let vm = makeViewModel()
		vm.mana = 5
		vm.maxMana = 30

		vm.applyToolEffectsFromDebug([.changeMana(-20)])
		#expect(vm.mana == 0)

		vm.applyToolEffectsFromDebug([.changeMana(999)])
		#expect(vm.mana == 30)
	}

	@Test func changeManaAppliesSignedDelta() {
		let vm = makeViewModel()
		vm.mana = 10
		vm.maxMana = 30

		vm.applyToolEffectsFromDebug([.changeMana(-3)])
		#expect(vm.mana == 7)

		vm.applyToolEffectsFromDebug([.changeMana(5)])
		#expect(vm.mana == 12)
	}
}

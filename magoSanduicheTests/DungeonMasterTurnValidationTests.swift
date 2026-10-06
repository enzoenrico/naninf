//
//  DungeonMasterTurnValidationTests.swift
//  magoSanduicheTests
//

import Foundation
import Testing
@testable import magoSanduiche

struct DungeonMasterTurnValidationTests {
	@Test func normalizedOptionsTrimsAndFiltersEmpty() {
		let result = DungeonMasterTurnValidation.normalizedOptions(from: [
			"  Fight  ",
			"",
			"  Flee  ",
		])
		#expect(result == ["Fight", "Flee"])
	}

	@Test func paddedOptionsFillsToThree() {
		let result = DungeonMasterTurnValidation.paddedOptions(from: ["Charge the door"])
		#expect(result.count == 3)
		#expect(result.first == "Charge the door")
	}

	@Test func paddedOptionsCapsAtThree() {
		let result = DungeonMasterTurnValidation.paddedOptions(from: [
			"One",
			"Two",
			"Three",
			"Four",
		])
		#expect(result == ["One", "Two", "Three"])
	}
}

struct DungeonMasterServiceTests {
	@Test @MainActor func generateFormatsContextAndResolvesDraft() async throws {
		let narrator = ScriptedNarrator(drafts: [.fixture(nextInput: .roll)])
		let dm = DungeonMasterService(narrator: narrator)
		let turn = try await dm.generate(context: .fixture(playerMessage: "I open the door"))

		#expect(narrator.prompts.count == 1)
		#expect(narrator.prompts[0].contains("playerMessage: I open the door"))
		#expect(turn.toolEffects.last == .requestAction(.roll))
	}

	@Test @MainActor func illustrateRejectsEmptyPrompt() async {
		let dm = DungeonMasterService(
			narrator: ScriptedNarrator(drafts: []),
			illustrator: ScriptedIllustrator()
		)
		await #expect(throws: SceneMediaError.emptyPrompt) {
			_ = try await dm.illustrate(visualPrompt: "   ")
		}
	}

	@Test @MainActor func generatePropagatesTypedFailure() async {
		let narrator = ScriptedNarrator(failure: .quotaReached(resetDate: nil))
		let dm = DungeonMasterService(narrator: narrator)
		await #expect(throws: DungeonMasterError.quotaReached(resetDate: nil)) {
			_ = try await dm.generate(context: .fixture(playerMessage: "hi"))
		}
	}
}

//
//  ChangeManaToolTests.swift
//  magoSanduicheTests
//

import Foundation
import Testing
@testable import magoSanduiche

struct ChangeManaToolTests {
	@Test func spendingManaReturnsNegativeEffect() async throws {
		let result = try await ChangeManaTool.call(arguments: .init(amount: -2))
		#expect(result.amount == -2)
		#expect(result.modelMessage == "Mana spent: 2")
		guard case let .changeMana(amount) = result.effects.first else {
			Issue.record("Expected a changeMana effect")
			return
		}
		#expect(amount == -2)
	}

	@Test func restoringManaReturnsPositiveEffect() async throws {
		let result = try await ChangeManaTool.call(arguments: .init(amount: 5))
		#expect(result.amount == 5)
		#expect(result.modelMessage == "Mana restored by 5")
		#expect(result.effects.count == 1)
	}

	@Test func zeroLeavesManaUnchanged() async throws {
		let result = try await ChangeManaTool.call(arguments: .init(amount: 0))
		#expect(result.modelMessage == "Mana unchanged")
	}

	@Test func amountIsClampedToValidRange() async throws {
		let high = try await ChangeManaTool.call(arguments: .init(amount: 999))
		#expect(high.amount == 30)

		let low = try await ChangeManaTool.call(arguments: .init(amount: -999))
		#expect(low.amount == -30)
	}

	@Test func changeManaEffectDescriptionRoundTrips() {
		#expect(GameToolEffect.changeMana(-3).description == "changeMana(-3)")
		#expect(GameToolEffect.changeMana(4).description == "changeMana(4)")
	}

	@Test @MainActor func modelToolsExposeChangeMana() {
		let names = DungeonMasterService.modelTools.map(\.name)
		#expect(names.contains(ChangeManaTool.name))
		#expect(ChangeManaTool.name == "changeMana")
	}
}

@MainActor
struct GameViewModelManaTests {
	@Test func changeManaClampsBetweenZeroAndMax() {
		let vm = GameViewModel(persistRunsToLibrary: false)
		vm.mana = 5
		vm.maxMana = 30

		vm.applyToolEffectsFromDebug([.changeMana(-20)])
		#expect(vm.mana == 0)

		vm.applyToolEffectsFromDebug([.changeMana(999)])
		#expect(vm.mana == 30)
	}

	@Test func changeManaAppliesSignedDelta() {
		let vm = GameViewModel(persistRunsToLibrary: false)
		vm.mana = 10
		vm.maxMana = 30

		vm.applyToolEffectsFromDebug([.changeMana(-3)])
		#expect(vm.mana == 7)

		vm.applyToolEffectsFromDebug([.changeMana(5)])
		#expect(vm.mana == 12)
	}
}

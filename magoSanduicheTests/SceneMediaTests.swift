//
//  SceneMediaTests.swift
//  magoSanduicheTests
//

import CoreGraphics
import Foundation
import Testing
@testable import magoSanduiche

struct SceneMediaTests {
	@Test @MainActor func illustrateReturnsASceneImage() async throws {
		let service = DungeonMasterService(
			narrator: ScriptedNarrator(drafts: []),
			illustrator: ScriptedIllustrator()
		)

		let scene = try await service.illustrate(visualPrompt: "Torchlit corridor")

		#expect(scene.cgImage.width == 1)
		#expect(scene.cgImage.height == 1)
	}
}

struct GameViewModelVisionTests {
	@MainActor
	private func makeViewModel() -> GameViewModel {
		GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: ScriptedIllustrator()
			)
		)
	}

	@Test @MainActor func introAllowsVisionBeforePlayerTurn() {
		let vm = makeViewModel()

		#expect(!vm.hasSubmittedPlayerTurn)
		#expect(vm.canOpenVisionTerminal)
		#expect(vm.visionDisplayMode == .introStatic)
	}

	@Test @MainActor func postIntroWithoutSceneBlocksVision() {
		let vm = makeViewModel()
		vm.hasSubmittedPlayerTurn = true
		vm.visionDisplayMode = .introStatic

		#expect(!vm.canOpenVisionTerminal)
	}

	@Test @MainActor func postIntroWithSceneAllowsVision() async throws {
		let vm = makeViewModel()
		vm.hasSubmittedPlayerTurn = true
		let image = try await ScriptedIllustrator().illustrate("torch")
		vm.visionDisplayMode = .scene(SceneImage(cgImage: image))

		#expect(vm.canOpenVisionTerminal)
	}

	@Test @MainActor func visionLoadingBlocksOpening() async throws {
		let vm = makeViewModel()
		vm.hasSubmittedPlayerTurn = true
		let image = try await ScriptedIllustrator().illustrate("torch")
		vm.visionDisplayMode = .scene(SceneImage(cgImage: image))
		vm.visionMediaLoading = true

		#expect(!vm.canOpenVisionTerminal)
	}
}

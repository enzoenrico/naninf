//
//  SceneMediaTests.swift
//  magoSanduicheTests
//

import Foundation
import Testing
@testable import magoSanduiche

struct SceneMediaTests {
	@Test @MainActor func generateSceneMediaRejectsEmptyPrompt() async {
		let service = DungeonMasterService(narrator: ScriptedNarrator(drafts: []))

		await #expect(throws: SceneMediaError.emptyPrompt) {
			_ = try await service.generateSceneMedia(visualPrompt: "   ")
		}
	}

	@Test @MainActor func generateSceneMediaHasNoRemoteImage() async {
		let service = DungeonMasterService(narrator: ScriptedNarrator(drafts: []))

		await #expect(throws: SceneMediaError.noImageURL) {
			_ = try await service.generateSceneMedia(visualPrompt: "Torchlit corridor")
		}
	}
}

struct GameViewModelVisionTests {
	@MainActor
	private func makeViewModel() -> GameViewModel {
		GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(narrator: ScriptedNarrator(drafts: []))
		)
	}

	@Test @MainActor func introAllowsVisionBeforePlayerTurn() {
		let vm = makeViewModel()

		#expect(!vm.hasSubmittedPlayerTurn)
		#expect(vm.canOpenVisionTerminal)
		#expect(vm.visionDisplayMode == .introStatic)
	}

	@Test @MainActor func postIntroWithoutRemoteMediaBlocksVision() {
		let vm = makeViewModel()
		vm.hasSubmittedPlayerTurn = true
		vm.visionDisplayMode = .introStatic

		#expect(!vm.canOpenVisionTerminal)
	}

	@Test @MainActor func postIntroWithRemoteMediaAllowsVision() {
		let vm = makeViewModel()
		vm.hasSubmittedPlayerTurn = true
		let url = URL(string: "https://cdn.example.com/scene.png")!
		vm.visionDisplayMode = .remote(SceneMediaResource(url: url, kind: .image))

		#expect(vm.canOpenVisionTerminal)
	}

	@Test @MainActor func visionLoadingBlocksOpening() {
		let vm = makeViewModel()
		vm.hasSubmittedPlayerTurn = true
		let url = URL(string: "https://cdn.example.com/scene.png")!
		vm.visionDisplayMode = .remote(SceneMediaResource(url: url, kind: .image))
		vm.visionMediaLoading = true

		#expect(!vm.canOpenVisionTerminal)
	}
}

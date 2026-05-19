//
//  SceneMediaTests.swift
//  magoSanduicheTests
//

import Foundation
import Testing
@testable import magoSanduiche

struct SceneMediaTests {
	@Test @MainActor func generateSceneMediaRejectsEmptyPrompt() async {
		let fake = FakeDungeonMasterModelClient()
		let service = DungeonMasterService(modelClient: fake)

		await #expect(throws: SceneMediaError.self) {
			_ = try await service.generateSceneMedia(visualPrompt: "   ")
		}
	}

	@Test @MainActor func generateSceneMediaReturnsImageResource() async throws {
		let expectedURL = URL(string: "https://cdn.example.com/omen.png")!
		let fake = FakeDungeonMasterModelClient()
		fake.generateSceneImageHandler = { prompt, _ in
			#expect(prompt == "Torchlit corridor")
			return expectedURL
		}
		let service = DungeonMasterService(modelClient: fake)

		let resource = try await service.generateSceneMedia(visualPrompt: "Torchlit corridor")

		#expect(resource.url == expectedURL)
		#expect(resource.kind == .image)
	}
}

struct GameViewModelVisionTests {
	@Test @MainActor func introAllowsVisionBeforePlayerTurn() {
		let vm = GameViewModel(persistRunsToLibrary: false)

		#expect(!vm.hasSubmittedPlayerTurn)
		#expect(vm.canOpenVisionTerminal)
		#expect(vm.visionDisplayMode == .introStatic)
	}

	@Test @MainActor func postIntroWithoutRemoteMediaBlocksVision() {
		let vm = GameViewModel(persistRunsToLibrary: false)
		vm.hasSubmittedPlayerTurn = true
		vm.visionDisplayMode = .introStatic

		#expect(!vm.canOpenVisionTerminal)
	}

	@Test @MainActor func postIntroWithRemoteMediaAllowsVision() {
		let vm = GameViewModel(persistRunsToLibrary: false)
		vm.hasSubmittedPlayerTurn = true
		let url = URL(string: "https://cdn.example.com/scene.png")!
		vm.visionDisplayMode = .remote(SceneMediaResource(url: url, kind: .image))

		#expect(vm.canOpenVisionTerminal)
	}

	@Test @MainActor func visionLoadingBlocksOpening() {
		let vm = GameViewModel(persistRunsToLibrary: false)
		vm.hasSubmittedPlayerTurn = true
		let url = URL(string: "https://cdn.example.com/scene.png")!
		vm.visionDisplayMode = .remote(SceneMediaResource(url: url, kind: .image))
		vm.visionMediaLoading = true

		#expect(!vm.canOpenVisionTerminal)
	}
}

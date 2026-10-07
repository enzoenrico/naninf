//
//  SceneMediaTests.swift
//  magoSanduicheTests
//

import CoreGraphics
import Foundation
import ImageIO
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

	@Test @MainActor func visualPromptBecomesTheSceneAndOpensThePanel() async throws {
		let vm = makeViewModel()
		let coordinator = AppCoordinator()
		coordinator.isImageCollapsed = true
		vm.attachCoordinator(coordinator)
		vm.hasSubmittedPlayerTurn = true

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", turnID: "turn")

		guard case .scene(let scene) = vm.visionDisplayMode else {
			Issue.record("expected a generated scene")
			return
		}
		#expect(scene.cgImage.width == 1)
		#expect(!vm.visionMediaLoading)
		#expect(!coordinator.isImageCollapsed)
	}

	@Test @MainActor func missingVisualPromptKeepsTheCurrentFrame() async {
		let vm = makeViewModel()
		let coordinator = AppCoordinator()
		coordinator.isImageCollapsed = true
		vm.attachCoordinator(coordinator)
		vm.hasSubmittedPlayerTurn = true
		vm.visionDisplayMode = .introStatic

		await vm.handleVisionAfterTurn(visualPrompt: nil, turnID: "turn")

		#expect(vm.visionDisplayMode == .introStatic)
		#expect(coordinator.isImageCollapsed)
	}

	@Test @MainActor func failedIllustrationKeepsThePreviousScene() async throws {
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: FailingIllustrator()
			)
		)
		let coordinator = AppCoordinator()
		vm.attachCoordinator(coordinator)
		vm.hasSubmittedPlayerTurn = true
		let image = try await ScriptedIllustrator().illustrate("torch")
		let previous = SceneImage(cgImage: image)
		vm.visionDisplayMode = .scene(previous)

		await vm.handleVisionAfterTurn(visualPrompt: "A dark stair", turnID: "turn")

		#expect(vm.visionDisplayMode == .scene(previous))
		#expect(!vm.visionMediaLoading)
	}

	@Test @MainActor func debugIllustrationShowsTheScene() async {
		let vm = makeViewModel()
		let coordinator = AppCoordinator()
		coordinator.isImageCollapsed = true
		vm.attachCoordinator(coordinator)

		let result = await vm.illustrateFromDebug(visualPrompt: "Torchlit corridor")

		#expect(result.didProduceImage)
		#expect(result.message.contains("1x1"))
		guard case .scene = vm.visionDisplayMode else {
			Issue.record("expected a generated scene")
			return
		}
		#expect(!vm.visionMediaLoading)
		#expect(!coordinator.isImageCollapsed)
	}

	@Test @MainActor func debugIllustrationRejectsAnEmptyPrompt() async {
		let vm = makeViewModel()
		vm.visionDisplayMode = .introStatic

		let result = await vm.illustrateFromDebug(visualPrompt: "   ")

		#expect(!result.didProduceImage)
		#expect(vm.visionDisplayMode == .introStatic)
		#expect(!vm.visionMediaLoading)
	}

	@Test @MainActor func debugIllustrationKeepsThePreviousSceneOnFailure() async throws {
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: FailingIllustrator()
			)
		)
		vm.hasSubmittedPlayerTurn = true
		let image = try await ScriptedIllustrator().illustrate("torch")
		let previous = SceneImage(cgImage: image)
		vm.visionDisplayMode = .scene(previous)

		let result = await vm.illustrateFromDebug(visualPrompt: "A dark stair")

		#expect(!result.didProduceImage)
		#expect(vm.visionDisplayMode == .scene(previous))
		#expect(!vm.visionMediaLoading)
	}

	@Test @MainActor func lockedGenerationDoesNotOpenTheSheet() async {
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: SheetIllustrator()
			)
		)
		vm.imagePlaygroundAvailabilityOverride = true
		vm.hasSubmittedPlayerTurn = true

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", turnID: "turn")

		#expect(SceneImageGeneration.isLocked)
		#expect(!vm.isImagePlaygroundPresented)
		#expect(vm.imagePlaygroundConcept.isEmpty)
		#expect(vm.visionDisplayMode == .introStatic)
	}

	@Test @MainActor func unavailablePlaygroundDoesNotPresent() async {
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: SheetIllustrator()
			)
		)
		vm.imagePlaygroundAvailabilityOverride = false
		vm.hasSubmittedPlayerTurn = true

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", turnID: "turn")

		#expect(!vm.isImagePlaygroundPresented)
		#expect(vm.visionDisplayMode == .introStatic)
	}

	@Test @MainActor func debugGenerationStaysLocked() async {
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: SheetIllustrator()
			)
		)
		vm.imagePlaygroundAvailabilityOverride = true

		let result = await vm.illustrateFromDebug(visualPrompt: "A cold stair")

		#expect(!result.shouldDismiss)
		#expect(!result.didProduceImage)
		#expect(vm.queuedDebugPlaygroundPrompt == nil)

		vm.consumeDebugPlaygroundRequest()

		#expect(!vm.isImagePlaygroundPresented)
		#expect(vm.imagePlaygroundConcept.isEmpty)
	}

	@Test @MainActor func acceptedPlaygroundFileBecomesTheScene() async throws {
		let vm = makeViewModel()
		let coordinator = AppCoordinator()
		coordinator.isImageCollapsed = true
		vm.attachCoordinator(coordinator)
		let image = try await ScriptedIllustrator().illustrate("torch")
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent("\(UUID().uuidString).png")
		guard
			let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
		else {
			Issue.record("could not create image destination")
			return
		}
		CGImageDestinationAddImage(destination, image, nil)
		#expect(CGImageDestinationFinalize(destination))

		vm.acceptPlaygroundImage(at: url)

		guard case .scene(let scene) = vm.visionDisplayMode else {
			Issue.record("expected a scene from the playground file")
			return
		}
		#expect(scene.cgImage.width == 1)
		#expect(!vm.isImagePlaygroundPresented)
		#expect(!coordinator.isImageCollapsed)
	}
}

private struct SheetIllustrator: SceneIllustrator {
	var illustratesWithSystemSheet: Bool { true }

	func illustrate(_ prompt: String) async throws -> CGImage {
		_ = prompt
		Issue.record("ImageCreator must not run on iOS 27")
		throw SceneMediaError.unavailable
	}
}

private struct FailingIllustrator: SceneIllustrator {
	func illustrate(_ prompt: String) async throws -> CGImage {
		_ = prompt
		throw SceneMediaError.unavailable
	}
}

//
//  DreamLiteIllustratorTests.swift
//  magoSanduicheTests
//

import CoreGraphics
import Foundation
import Testing
@testable import magoSanduiche

struct DreamLiteIllustratorTests {
	@Test @MainActor func defaultsToTheSharedOnDeviceGenerator() {
		let illustrator = DreamLiteIllustrator()

		#expect(illustrator.generator as? DreamLiteOnDeviceGenerator === DreamLiteOnDeviceGenerator.shared)
		#expect(!illustrator.illustratesWithSystemSheet)
	}

	@Test @MainActor func generatedImagesBecomeTheRenderedScene() async throws {
		let generator = StubGenerator(result: .success(try solidImage(width: 4, height: 2)))
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: DreamLiteIllustrator(generator: generator)
			)
		)
		vm.hasSubmittedPlayerTurn = true

		await vm.handleVisionAfterTurn(visualPrompt: "  Torchlit corridor  ", prompt: visionPrompt(), turnID: "turn")

		guard case .scene(let scene) = vm.visionDisplayMode else {
			Issue.record("expected a DreamLite scene")
			return
		}
		#expect(scene.cgImage.width == 4)
		#expect(scene.cgImage.height == 2)
		#expect(!vm.visionMediaLoading)
		#expect(await generator.prompts == ["Torchlit corridor"])
	}

	@Test @MainActor func generationFailuresKeepTheCurrentFrame() async {
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: DreamLiteIllustrator(generator: StubGenerator(result: .failure(DreamLiteError.modelsUnavailable)))
			)
		)
		vm.hasSubmittedPlayerTurn = true

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", prompt: visionPrompt(), turnID: "turn")

		#expect(vm.visionDisplayMode == .introStatic)
		#expect(!vm.visionMediaLoading)
	}

	@Test @MainActor func newerPromptsWinOverSlowerEarlierOnes() async throws {
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: DelayedIllustrator()
			)
		)
		vm.hasSubmittedPlayerTurn = true

		let slowTurn = Task { await vm.handleVisionAfterTurn(visualPrompt: "slow", prompt: visionPrompt(), turnID: "turn-1") }
		try await Task.sleep(for: .milliseconds(20))
		await vm.handleVisionAfterTurn(visualPrompt: "fast", prompt: visionPrompt(), turnID: "turn-2")
		await slowTurn.value

		guard case .scene(let scene) = vm.visionDisplayMode else {
			Issue.record("expected the newer scene")
			return
		}
		#expect(scene.cgImage.width == 1)
		#expect(!vm.visionMediaLoading)
	}
}

private actor StubGenerator: DreamLiteImageGenerating {
	private let result: Result<CGImage, Error>
	private(set) var prompts: [String] = []

	init(result: Result<CGImage, Error>) {
		self.result = result
	}

	func generateImage(prompt: String) async throws -> CGImage {
		prompts.append(prompt)
		return try result.get()
	}
}

/// "slow" yields a 2×2 image after a delay; anything else yields 1×1 immediately.
private struct DelayedIllustrator: SceneIllustrator {
	func illustrate(_ prompt: String) async throws -> CGImage {
		if prompt == "slow" {
			try await Task.sleep(for: .milliseconds(200))
			return try solidImage(width: 2, height: 2)
		}
		return try solidImage(width: 1, height: 1)
	}
}

@MainActor
private func visionPrompt() -> PlayerPromptID {
	PlayerPromptID(TerminalEntry(kind: .player, text: "look"))!
}

private func solidImage(width: Int, height: Int) throws -> CGImage {
	guard
		let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: width,
			space: CGColorSpaceCreateDeviceGray(),
			bitmapInfo: CGImageAlphaInfo.none.rawValue
		),
		let image = context.makeImage()
	else {
		throw SceneMediaError.noImage
	}
	return image
}

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

	@Test @MainActor func illustrateFramesASquareCanvasToSixteenByNine() async throws {
		let service = DungeonMasterService(
			narrator: ScriptedNarrator(drafts: []),
			illustrator: FixedIllustrator(image: try solidSceneImage(width: 32, height: 32))
		)

		let scene = try await service.illustrate(visualPrompt: "Torchlit corridor")

		#expect(scene.cgImage.width == 32)
		#expect(scene.cgImage.height == 18)
	}
}

struct AsciiVisionSpinnerTests {
	@Test func framesStayOnOneGridAndTheArmTurns() {
		let up = AsciiVisionSpinnerArt.lines(for: 0)
		let turned = AsciiVisionSpinnerArt.lines(for: 1)

		#expect(up.count == AsciiVisionSpinnerArt.rows)
		#expect(up.allSatisfy { $0.count == AsciiVisionSpinnerArt.columns })
		#expect(up != turned)
		#expect(AsciiVisionSpinnerArt.lines(for: AsciiVisionSpinnerArt.frameCount) == up)
		#expect(up.joined().contains("@"))
		#expect(up.flatMap(\.unicodeScalars).filter { !$0.properties.isWhitespace }.count > 20)
	}
}

struct SceneFrameTests {
	@Test func squareImageCropsToThePlaceholderAspect() throws {
		let framed = SceneFrame.widescreen(try solidSceneImage(width: 32, height: 32))

		#expect(framed.width == 32)
		#expect(framed.height == 18)
	}

	@Test func widescreenImageIsLeftAlone() throws {
		let framed = SceneFrame.widescreen(try solidSceneImage(width: 32, height: 18))

		#expect(framed.width == 32)
		#expect(framed.height == 18)
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

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", prompt: visionPrompt(), turnID: "turn")

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

		await vm.handleVisionAfterTurn(visualPrompt: nil, prompt: visionPrompt(), turnID: "turn")

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
		coordinator.isImageCollapsed = false
		vm.attachCoordinator(coordinator)
		vm.hasSubmittedPlayerTurn = true
		let image = try await ScriptedIllustrator().illustrate("torch")
		let previous = SceneImage(cgImage: image)
		vm.visionDisplayMode = .scene(previous)

		await vm.handleVisionAfterTurn(visualPrompt: "A dark stair", prompt: visionPrompt(), turnID: "turn")

		#expect(vm.visionDisplayMode == .scene(previous))
		#expect(!vm.visionMediaLoading)
		#expect(vm.visionGenerationPercent == nil)
		#expect(coordinator.isImageCollapsed)
	}

	@Test @MainActor func generationClosesThePreviewUntilTheImageExists() async throws {
		let gate = GenerationGate()
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: GatedIllustrator(gate: gate)
			)
		)
		let coordinator = AppCoordinator()
		coordinator.isImageCollapsed = false
		vm.attachCoordinator(coordinator)
		vm.hasSubmittedPlayerTurn = true

		let turn = Task { await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", prompt: visionPrompt(), turnID: "turn") }
		await gate.waitUntilStarted()

		#expect(coordinator.isImageCollapsed)
		#expect(vm.visionMediaLoading)
		#expect(vm.visionGenerationPercent == 42)
		#expect(vm.visionDisplayMode == .introStatic)

		gate.release()
		await turn.value

		guard case .scene = vm.visionDisplayMode else {
			Issue.record("expected a generated scene")
			return
		}
		#expect(!vm.visionMediaLoading)
		#expect(vm.visionGenerationPercent == nil)
		#expect(!coordinator.isImageCollapsed)
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

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", prompt: visionPrompt(), turnID: "turn")

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

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", prompt: visionPrompt(), turnID: "turn")

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

private struct FixedIllustrator: SceneIllustrator {
	let image: CGImage

	func illustrate(_ prompt: String) async throws -> CGImage {
		_ = prompt
		return image
	}
}

private struct GatedIllustrator: SceneIllustrator {
	let gate: GenerationGate

	func illustrate(_ prompt: String) async throws -> CGImage {
		try await illustrate(prompt, progress: .ignored)
	}

	func illustrate(_ prompt: String, progress: SceneIllustrationProgress) async throws -> CGImage {
		_ = prompt
		progress.update(0.42)
		await gate.markStartedAndWait()
		return try solidSceneImage(width: 16, height: 16)
	}
}

private final class GenerationGate: @unchecked Sendable {
	private let lock = NSLock()
	private var didStart = false
	private var startWaiter: CheckedContinuation<Void, Never>?
	private var releaseWaiter: CheckedContinuation<Void, Never>?
	private var isReleased = false

	func markStartedAndWait() async {
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			lock.lock()
			didStart = true
			let waiter = startWaiter
			startWaiter = nil
			if isReleased {
				lock.unlock()
				waiter?.resume()
				continuation.resume()
				return
			}
			releaseWaiter = continuation
			lock.unlock()
			waiter?.resume()
		}
	}

	func waitUntilStarted() async {
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			lock.lock()
			if didStart {
				lock.unlock()
				continuation.resume()
			} else {
				startWaiter = continuation
				lock.unlock()
			}
		}
	}

	func release() {
		lock.lock()
		isReleased = true
		let waiter = releaseWaiter
		releaseWaiter = nil
		lock.unlock()
		waiter?.resume()
	}
}

private func solidSceneImage(width: Int, height: Int) throws -> CGImage {
	let colorSpace = CGColorSpaceCreateDeviceGray()
	guard
		let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: width,
			space: colorSpace,
			bitmapInfo: CGImageAlphaInfo.none.rawValue
		),
		let image = context.makeImage()
	else {
		throw SceneMediaError.noImage
	}
	return image
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

@MainActor
private func visionPrompt() -> PlayerPromptID {
	PlayerPromptID(TerminalEntry(kind: .player, text: "look"))!
}

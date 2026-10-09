//
//  SceneArchiveTests.swift
//  magoSanduicheTests
//

import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import magoSanduiche

struct SceneArchiveTests {
	@Test @MainActor func displayedSceneIsTappableBeforeTheQueryRefreshes() {
		let prompts = RecallablePrompts(scenes: [])
		let player = TerminalEntry(kind: .player, text: "look")
		let narrator = TerminalEntry(kind: .dungeonMaster, text: "The hall.")

		#expect(prompts.prompt(for: player, displayedImageID: player.id)?.entryID == player.id)
		#expect(prompts.prompt(for: player, displayedImageID: UUID()) == nil)
		#expect(prompts.prompt(for: player) == nil)
		#expect(prompts.prompt(for: narrator, displayedImageID: narrator.id) == nil)
	}

	@Test @MainActor func playerPromptIDMatchesOnlyPlayerLines() {
		let player = TerminalEntry(id: UUID(), kind: .player, text: "open the door")
		let prompt = PlayerPromptID(player)

		#expect(prompt?.entryID == player.id)
		#expect(PlayerPromptID(TerminalEntry(kind: .dungeonMaster, text: "The door opens.")) == nil)
		#expect(PlayerPromptID(TerminalEntry(kind: .dice, text: "12")) == nil)
		#expect(PlayerPromptID(TerminalEntry(kind: .system, text: "The lock holds.")) == nil)
	}

	@Test @MainActor func keepTwiceLeavesOneScene() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let archive = SceneArchive.open(runID: runID, context: context)
		let prompt = try player("look")

		#expect(await archive.keep(SceneImage(cgImage: try bitmap(width: 4, height: 2)), for: prompt))
		#expect(await archive.keep(SceneImage(cgImage: try bitmap(width: 6, height: 3)), for: prompt))

		let rows = try context.fetch(FetchDescriptor<StoredScene>())
		#expect(rows.count == 1)
		#expect(rows[0].promptID == prompt.entryID)
		let decoded = try #require(archive.image(for: prompt))
		#expect(decoded.cgImage.width == 6)
		#expect(decoded.cgImage.height == 3)
	}

	@Test @MainActor func transcriptSaveLeavesBothScenes() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let archive = SceneArchive.open(runID: runID, context: context)
		let north = TerminalEntry(kind: .player, text: "look north")
		let south = TerminalEntry(kind: .player, text: "look south")
		let promptNorth = try #require(PlayerPromptID(north))
		let promptSouth = try #require(PlayerPromptID(south))

		await archive.keep(SceneImage(cgImage: try bitmap(width: 4, height: 2)), for: promptNorth)
		await archive.keep(SceneImage(cgImage: try bitmap(width: 8, height: 4)), for: promptSouth)

		let vm = viewModel(persistRunsToLibrary: true)
		vm.modelContext = context
		vm.persistedRunID = runID
		vm.terminalEntries = [north, south]
		vm.persistRun()

		let stored = try #require(GameRunSnapshotMapper.fetch(id: runID, context: context))
		let lines = GameRunSnapshotMapper.terminalEntries(from: stored.transcriptBlob)
		#expect(lines.map(\.text) == ["look north", "look south"])
		let rows = try context.fetch(FetchDescriptor<StoredScene>())
		#expect(Set(rows.map(\.promptID)) == [promptNorth.entryID, promptSouth.entryID])
	}

	@Test @MainActor func keepAfterTheRunIsDeletedInsertsNothing() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let archive = SceneArchive.open(runID: runID, context: context)
		let run = try #require(GameRunSnapshotMapper.fetch(id: runID, context: context))
		context.delete(run)
		try context.save()

		#expect(
			await archive.keep(SceneImage(cgImage: try bitmap(width: 4, height: 2)), for: try player("look"))
				== false
		)

		#expect(try context.fetch(FetchDescriptor<StoredScene>()).isEmpty)
	}

	@Test @MainActor func deletingARunDeletesItsScenesOnly() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let keptRunID = UUID()
		let deletedRunID = UUID()
		try insertRun(id: keptRunID, into: context)
		try insertRun(id: deletedRunID, into: context)
		let keptArchive = SceneArchive.open(runID: keptRunID, context: context)
		let deletedArchive = SceneArchive.open(runID: deletedRunID, context: context)
		let keptPrompt = try player("stay")
		let deletedPrompt = try player("go")
		await keptArchive.keep(SceneImage(cgImage: try bitmap(width: 4, height: 2)), for: keptPrompt)
		await deletedArchive.keep(SceneImage(cgImage: try bitmap(width: 5, height: 2)), for: deletedPrompt)

		let deletedRun = try #require(GameRunSnapshotMapper.fetch(id: deletedRunID, context: context))
		context.delete(deletedRun)
		try context.save()

		let rows = try context.fetch(FetchDescriptor<StoredScene>())
		#expect(rows.map(\.promptID) == [keptPrompt.entryID])
		#expect(keptArchive.image(for: keptPrompt)?.cgImage.width == 4)
		#expect(deletedArchive.image(for: deletedPrompt) == nil)
	}

	@Test @MainActor func storedBitmapMatchesTheTightCrop() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let archive = SceneArchive.open(runID: runID, context: context)
		let prompt = try player("look")
		let backing = try bitmap(width: 40, height: 30)
		let tight = try #require(backing.cropping(to: CGRect(x: 4, y: 6, width: 16, height: 9)))

		await archive.keep(SceneImage(cgImage: tight), for: prompt)

		let decoded = try #require(archive.image(for: prompt))
		#expect(tight.width == 16)
		#expect(tight.height == 9)
		#expect(decoded.cgImage.width == tight.width)
		#expect(decoded.cgImage.height == tight.height)
		#expect(decoded.cgImage.width != backing.width)
		#expect(decoded.id == prompt.entryID)
	}

	@Test @MainActor func undecodablePNGIsRemoved() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		let run = try insertRun(id: runID, into: context)
		let archive = SceneArchive.open(runID: runID, context: context)
		let prompt = try player("look")
		context.insert(
			StoredScene(
				promptID: prompt.entryID,
				runID: runID,
				png: Data([0x00, 0x01, 0x02]),
				run: run
			)
		)
		try context.save()

		#expect(archive.image(for: prompt) == nil)
		#expect(try context.fetch(FetchDescriptor<StoredScene>()).count == 0)
	}

	@Test @MainActor func onboardingDoesNotOpenAnArchive() throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)

		let onboarding = viewModel(persistRunsToLibrary: false)
		onboarding.modelContext = context
		onboarding.persistedRunID = runID
		#expect(onboarding.sceneArchive == nil)

		let library = viewModel(persistRunsToLibrary: true)
		#expect(library.sceneArchive == nil)
		library.modelContext = context
		#expect(library.sceneArchive == nil)
		library.persistedRunID = runID
		#expect(library.sceneArchive != nil)
	}

	@Test @MainActor func appendPlayerLineIsThePlayerEntry() {
		let vm = viewModel(persistRunsToLibrary: false)
		vm.terminalEntries = []
		let prompt = vm.appendPlayerLine("open the door")

		#expect(vm.terminalEntries.count == 1)
		#expect(vm.terminalEntries[0].kind == .player)
		#expect(vm.terminalEntries[0].text == "open the door")
		#expect(vm.terminalEntries[0].id == prompt.entryID)
	}

	@Test @MainActor func restoreRecallsTheLatestStoredSceneAndLeavesThePanelCollapsed() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let archive = SceneArchive.open(runID: runID, context: context)
		let older = TerminalEntry(kind: .player, text: "older")
		let newer = TerminalEntry(kind: .player, text: "newer")
		let plain = TerminalEntry(kind: .player, text: "plain")
		let olderPrompt = try #require(PlayerPromptID(older))
		let newerPrompt = try #require(PlayerPromptID(newer))
		await archive.keep(SceneImage(cgImage: try bitmap(width: 8, height: 4)), for: olderPrompt)
		await archive.keep(SceneImage(cgImage: try bitmap(width: 6, height: 3)), for: newerPrompt)

		let vm = viewModel(persistRunsToLibrary: true)
		vm.modelContext = context
		vm.persistedRunID = runID
		vm.terminalEntries = [
			older,
			TerminalEntry(kind: .dungeonMaster, text: "The hall."),
			newer,
			TerminalEntry(kind: .dice, text: "4"),
			plain,
		]
		vm.persistRun()
		let coordinator = AppCoordinator()
		coordinator.isImageCollapsed = true
		vm.attachCoordinator(coordinator)

		vm.restore(runID: runID, modelContext: context)

		guard case .recalled(let prompt, let image) = vm.visionDisplayMode else {
			Issue.record("expected the newest stored scene")
			return
		}
		#expect(prompt == newerPrompt)
		#expect(image.cgImage.width == 6)
		#expect(image.cgImage.height == 3)
		#expect(image.id == newerPrompt.entryID)
		#expect(coordinator.isImageCollapsed)
	}

	@Test @MainActor func restoreWithoutASceneStaysOnTheIntro() throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let vm = viewModel(persistRunsToLibrary: true)

		vm.restore(runID: runID, modelContext: context)

		#expect(vm.visionDisplayMode == .introStatic)
	}

	@Test @MainActor func illustrationKeepsTheSceneForThatPrompt() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let vm = viewModel(persistRunsToLibrary: true)
		vm.modelContext = context
		vm.persistedRunID = runID
		vm.hasSubmittedPlayerTurn = true
		let prompt = try player("look")

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", prompt: prompt, turnID: "turn")

		guard case .scene(let scene) = vm.visionDisplayMode else {
			Issue.record("expected the generated scene")
			return
		}
		#expect(scene.id == prompt.entryID)
		#expect(vm.storedSceneRevision == 1)
		let rows = try context.fetch(FetchDescriptor<StoredScene>())
		#expect(rows.count == 1)
		#expect(rows[0].promptID == prompt.entryID)
	}

	@Test @MainActor func failedIllustrationStoresNothing() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let vm = viewModel(persistRunsToLibrary: true, illustrator: FailingSceneIllustrator())
		vm.modelContext = context
		vm.persistedRunID = runID
		vm.hasSubmittedPlayerTurn = true

		await vm.handleVisionAfterTurn(visualPrompt: "A dark stair", prompt: try player("look"), turnID: "turn")

		#expect(vm.visionDisplayMode == .introStatic)
		#expect(try context.fetch(FetchDescriptor<StoredScene>()).isEmpty)
	}

	@Test @MainActor func aSupersededIllustrationIsStoredButNotShown() async throws {
		let store = try ArchiveStore()
		let context = store.context
		let runID = UUID()
		try insertRun(id: runID, into: context)
		let gate = IllustrationGate()
		let vm = viewModel(persistRunsToLibrary: true, illustrator: GatedSceneIllustrator(gate: gate))
		vm.modelContext = context
		vm.persistedRunID = runID
		vm.hasSubmittedPlayerTurn = true
		let slow = try player("slow")
		let fast = try player("fast")

		let slowTurn = Task {
			await vm.handleVisionAfterTurn(visualPrompt: "slow", prompt: slow, turnID: "slow")
		}
		await gate.waitUntilStarted()
		await vm.handleVisionAfterTurn(visualPrompt: "fast", prompt: fast, turnID: "fast")
		gate.release()
		await slowTurn.value

		guard case .scene(let scene) = vm.visionDisplayMode else {
			Issue.record("expected the newer scene")
			return
		}
		#expect(scene.id == fast.entryID)
		#expect(scene.cgImage.width == 32)
		#expect(scene.cgImage.height == 18)
		let rows = try context.fetch(FetchDescriptor<StoredScene>())
		#expect(Set(rows.map(\.promptID)) == [slow.entryID, fast.entryID])
		let storedSlow = try #require(vm.sceneArchive?.image(for: slow))
		#expect(storedSlow.cgImage.width == 16)
		#expect(storedSlow.cgImage.height == 9)
	}
}

@MainActor
private struct ArchiveStore {
	let container: ModelContainer

	var context: ModelContext { container.mainContext }

	init() throws {
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		container = try ModelContainer(
			for: Schema(GameRunPersistSchema.models),
			configurations: [configuration]
		)
	}
}

@MainActor
private func insertRun(id: UUID, into context: ModelContext) throws -> StoredGameRun {
	let live = GameRunSnapshotMapper.LiveState(
		terminalEntries: [TerminalEntry(kind: .dungeonMaster, text: "A room.")],
		suggestedOptions: [],
		health: 50,
		mana: 20,
		maxHealth: 50,
		maxMana: 30,
		diceValue: 20,
		pendingDiceRoll: nil,
		diceRevealStage: .idle,
		diceResultText: "cold",
		invalidInputAttempts: 0,
		contextualInput: "",
		contextAction: .write,
		uiPhase: .ready,
		suppressTerminalAnimations: true
	)
	let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
	let fields = try GameRunSnapshotMapper.snapshotFields(from: live, createdAt: createdAt)
	let run = GameRunSnapshotMapper.makeStoredGameRun(
		id: id,
		createdAt: createdAt,
		updatedAt: createdAt,
		fields: fields,
		analyticsSessionID: "test"
	)
	context.insert(run)
	try context.save()
	return run
}

@MainActor
private func viewModel(
	persistRunsToLibrary: Bool,
	illustrator: any SceneIllustrator = ScriptedIllustrator()
) -> GameViewModel {
	GameViewModel(
		persistRunsToLibrary: persistRunsToLibrary,
		dungeonMaster: DungeonMasterService(
			narrator: ScriptedNarrator(drafts: []),
			illustrator: illustrator
		)
	)
}

@MainActor
private func player(_ text: String) throws -> PlayerPromptID {
	try #require(PlayerPromptID(TerminalEntry(kind: .player, text: text)))
}

private func bitmap(width: Int, height: Int) throws -> CGImage {
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

private struct FailingSceneIllustrator: SceneIllustrator {
	func illustrate(_ prompt: String) async throws -> CGImage {
		_ = prompt
		throw SceneMediaError.unavailable
	}
}

private struct GatedSceneIllustrator: SceneIllustrator {
	let gate: IllustrationGate

	func illustrate(_ prompt: String) async throws -> CGImage {
		if prompt == "slow" {
			await gate.markStartedAndWait()
			return try bitmap(width: 16, height: 9)
		}
		return try bitmap(width: 32, height: 18)
	}
}

private final class IllustrationGate: @unchecked Sendable {
	private let lock = NSLock()
	private var didStart = false
	private var startWaiter: CheckedContinuation<Void, Never>?
	private var releaseWaiter: CheckedContinuation<Void, Never>?

	func markStartedAndWait() async {
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			lock.lock()
			didStart = true
			let waiter = startWaiter
			startWaiter = nil
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
				return
			}
			startWaiter = continuation
			lock.unlock()
		}
	}

	func release() {
		lock.lock()
		let waiter = releaseWaiter
		releaseWaiter = nil
		lock.unlock()
		waiter?.resume()
	}
}

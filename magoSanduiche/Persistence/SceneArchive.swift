//
//  SceneArchive.swift
//  magoSanduiche
//

import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@Model
final class StoredScene {
	@Attribute(.unique) var promptID: UUID
	var runID: UUID
	@Attribute(.externalStorage) var png: Data
	var run: StoredGameRun?

	init(promptID: UUID, runID: UUID, png: Data, run: StoredGameRun?) {
		self.promptID = promptID
		self.runID = runID
		self.png = png
		self.run = run
	}
}

struct SceneArchive {
	private let runID: UUID
	private let context: ModelContext

	fileprivate init(runID: UUID, context: ModelContext) {
		self.runID = runID
		self.context = context
	}

	static func open(runID: UUID, context: ModelContext) -> SceneArchive {
		SceneArchive(runID: runID, context: context)
	}

	func keep(_ image: SceneImage, for prompt: PlayerPromptID) async {
		let source = image.cgImage
		let png = await Task.detached(priority: .utility) {
			ScenePNG.data(from: source)
		}.value
		guard let png else { return }
		guard let run = GameRunSnapshotMapper.fetch(id: runID, context: context) else { return }

		let promptID = prompt.entryID
		if let existing = storedScene(promptID: promptID) {
			existing.png = png
			savePNG(png, promptID: promptID, pendingInsert: nil)
			return
		}

		let row = StoredScene(promptID: promptID, runID: runID, png: png, run: run)
		context.insert(row)
		savePNG(png, promptID: promptID, pendingInsert: row)
	}

	func image(for prompt: PlayerPromptID) -> SceneImage? {
		guard let row = storedScene(promptID: prompt.entryID) else { return nil }
		guard let cgImage = ScenePNG.image(from: row.png) else {
			context.delete(row)
			try? context.save()
			return nil
		}
		return SceneImage(cgImage: cgImage, id: prompt.entryID)
	}

	private func savePNG(_ png: Data, promptID: UUID, pendingInsert: StoredScene?) {
		do {
			try context.save()
		} catch {
			// A unique promptID does not upsert. 133021 is the constraint-merge error.
			guard isUniqueConflict(error) else {
				if let pendingInsert {
					context.delete(pendingInsert)
				}
				return
			}
			if let pendingInsert {
				context.delete(pendingInsert)
			}
			guard let existing = storedScene(promptID: promptID, excluding: pendingInsert) else { return }
			existing.png = png
			try? context.save()
		}
	}

	private func storedScene(promptID: UUID, excluding: StoredScene? = nil) -> StoredScene? {
		var descriptor = FetchDescriptor<StoredScene>(
			predicate: #Predicate { $0.promptID == promptID }
		)
		descriptor.fetchLimit = excluding == nil ? 1 : 2
		let rows = (try? context.fetch(descriptor)) ?? []
		return rows.first { row in
			guard let excluding else { return true }
			return row !== excluding
		}
	}

	private func isUniqueConflict(_ error: Error) -> Bool {
		let nsError = error as NSError
		if nsError.domain == NSCocoaErrorDomain, nsError.code == 133021 {
			return true
		}
		if nsError.domain == "NSSQLiteErrorDomain", nsError.code == 19 {
			return true
		}
		if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
			return isUniqueConflict(underlying)
		}
		return false
	}
}

private nonisolated enum ScenePNG {
	static func data(from image: CGImage) -> Data? {
		guard let tight = redrawnBitmap(image) else { return nil }
		let buffer = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(
			buffer,
			UTType.png.identifier as CFString,
			1,
			nil
		) else { return nil }
		CGImageDestinationAddImage(destination, tight, nil)
		guard CGImageDestinationFinalize(destination) else { return nil }
		return buffer as Data
	}

	static func image(from data: Data) -> CGImage? {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
		return CGImageSourceCreateImageAtIndex(source, 0, nil)
	}

	private static func redrawnBitmap(_ image: CGImage) -> CGImage? {
		let width = image.width
		let height = image.height
		guard width > 0, height > 0 else { return nil }
		let bounds = CGRect(x: 0, y: 0, width: width, height: height)
		if let matched = context(width: width, height: height, matching: image) {
			matched.draw(image, in: bounds)
			if let copy = matched.makeImage(), copy.width == width, copy.height == height {
				return copy
			}
		}
		guard let fallback = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }
		fallback.draw(image, in: bounds)
		guard let copy = fallback.makeImage(), copy.width == width, copy.height == height else { return nil }
		return copy
	}

	private static func context(width: Int, height: Int, matching image: CGImage) -> CGContext? {
		guard let colorSpace = image.colorSpace else { return nil }
		return CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: image.bitsPerComponent,
			bytesPerRow: 0,
			space: colorSpace,
			bitmapInfo: image.bitmapInfo.rawValue
		)
	}
}

struct RecallablePrompts {
	private let promptIDs: Set<UUID>

	init(scenes: [StoredScene]) {
		promptIDs = Set(scenes.map(\.promptID))
	}

	func prompt(for entry: TerminalEntry, displayedImageID: UUID? = nil) -> PlayerPromptID? {
		guard let prompt = PlayerPromptID(entry) else { return nil }
		if promptIDs.contains(prompt.entryID) { return prompt }
		guard displayedImageID == prompt.entryID else { return nil }
		return prompt
	}
}

struct RecallablePromptsReader<Content: View>: View {
	private let runID: UUID?
	private let content: (RecallablePrompts) -> Content

	init(run: UUID?, @ViewBuilder content: @escaping (RecallablePrompts) -> Content) {
		self.runID = run
		self.content = content
	}

	var body: some View {
		if let runID {
			RecallableSceneQuery(runID: runID, content: content)
				.id(runID)
		} else {
			content(RecallablePrompts(scenes: []))
		}
	}
}

private struct RecallableSceneQuery<Content: View>: View {
	@Query private var scenes: [StoredScene]
	private let content: (RecallablePrompts) -> Content

	init(runID: UUID, @ViewBuilder content: @escaping (RecallablePrompts) -> Content) {
		let queriedRunID = runID
		_scenes = Query(filter: #Predicate<StoredScene> { $0.runID == queriedRunID })
		self.content = content
	}

	var body: some View {
		content(RecallablePrompts(scenes: scenes))
	}
}

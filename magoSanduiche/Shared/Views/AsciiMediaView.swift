//
//  AsciiMediaView.swift
//  magoSanduiche
//
//  Created by Cursor on 05/05/26.
//

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

#if canImport(UIKit)
	import UIKit
#endif

private let asciiMediaDefaultCharacters = "  .*░▒▓█"

enum AsciiMediaScaleMode: String {
	case fit
	case fill

	var contentMode: ContentMode {
		switch self {
		case .fit: .fit
		case .fill: .fill
		}
	}
}

struct AsciiMediaView: View {
	typealias ScaleMode = AsciiMediaScaleMode

	enum Source {
		case image(CGImage)
		case imageFile(URL)
		case remoteImage(URL)
		case videoFile(URL)
		case remoteVideo(URL)

		#if canImport(UIKit)
			case catalogVideo(named: String)
			case uiImage(UIImage)
		#endif

		var cacheKey: String {
			switch self {
			case .image(let image):
				"image:\(ObjectIdentifier(image).hashValue)"
			case .imageFile(let url):
				"image-file:\(url.absoluteString)"
			case .remoteImage(let url):
				"remote-image:\(url.absoluteString)"
			case .videoFile(let url):
				"video-file:\(url.absoluteString)"
			case .remoteVideo(let url):
				"remote-video:\(url.absoluteString)"
			#if canImport(UIKit)
				case .catalogVideo(let name):
					"catalog-video:\(name)"
				case .uiImage(let image):
					"ui-image:\(ObjectIdentifier(image).hashValue)"
			#endif
			}
		}

		var isVideo: Bool {
			switch self {
			case .videoFile, .remoteVideo:
				true
			case .image, .imageFile, .remoteImage:
				false
			#if canImport(UIKit)
				case .catalogVideo:
					true
				case .uiImage:
					false
			#endif
			}
		}
	}

	static let defaultCharacters = asciiMediaDefaultCharacters

	let source: Source

	private var configuration = AsciiMediaConfiguration()

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var phase: AsciiMediaPhase = .idle
	@State private var currentFrameIndex = 0

	init(source: Source) {
		self.source = source
	}

	#if canImport(UIKit)
		init(image: UIImage) {
			self.source = .uiImage(image)
		}
	#endif

	init(image: CGImage) {
		self.source = .image(image)
	}

	init(imageURL: URL, isRemote: Bool = false) {
		self.source = isRemote ? .remoteImage(imageURL) : .imageFile(imageURL)
	}

	init(videoURL: URL, isRemote: Bool = false) {
		self.source = isRemote ? .remoteVideo(videoURL) : .videoFile(videoURL)
	}

	#if canImport(UIKit)
		init(catalogVideoNamed name: String) {
			self.source = .catalogVideo(named: name)
		}
	#endif

	var body: some View {
		content
			.frame(maxWidth: .infinity)
			.background(configuration.background)
			.clipped()
			.task(id: loadIdentity) {
				await loadMedia()
			}
			.task(id: playbackIdentity) {
				await runPlayback()
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(accessibilityLabel)
			.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	@ViewBuilder
	private var content: some View {
		switch phase {
		case .idle, .loading:
			AsciiMediaStatusView(
				title: "ASCII MEDIA",
				message: source.isVideo ? "preloading video frames" : "preloading image",
				isLoading: true,
				configuration: configuration
			)
		case .failed(let message):
			AsciiMediaStatusView(
				title: "ASCII ERROR",
				message: message,
				isLoading: false,
				configuration: configuration
			)
		case .ready(let frames):
			if frames.isEmpty {
				AsciiMediaStatusView(
					title: "ASCII ERROR",
					message: "no frames decoded",
					isLoading: false,
					configuration: configuration
				)
			} else {
				let frame = frames[min(currentFrameIndex, frames.count - 1)]
				asciiFrameView(frame)
			}
		}
	}

	@ViewBuilder
	private func asciiFrameView(_ frame: AsciiMediaFrame) -> some View {
		switch configuration.scaleMode {
		case .fit:
			AsciiMediaCanvas(frame: frame, configuration: configuration)
				.aspectRatio(frame.displayAspectRatio, contentMode: .fit)
		case .fill:
			AsciiMediaCanvas(frame: frame, configuration: configuration)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.clipped()
		}
	}

	private var loadIdentity: String {
		[
			source.cacheKey,
			"\(configuration.columns)",
			"\(configuration.maxRows ?? -1)",
			configuration.scaleMode.rawValue,
			"\(configuration.preservesAspectRatio)",
			configuration.sanitizedCharacters,
			"\(configuration.frameRate)",
			"\(configuration.maxVideoFrames)",
			"\(configuration.fontSize)",
		].joined(separator: "|")
	}

	private var playbackIdentity: String {
		switch phase {
		case .ready(let frames):
			"\(loadIdentity)|frames:\(frames.count)|reduce-motion:\(reduceMotion)"
		case .idle, .loading, .failed:
			"\(loadIdentity)|inactive"
		}
	}

	private var accessibilityLabel: String {
		switch phase {
		case .idle:
			"ASCII media waiting to load"
		case .loading:
			"ASCII media loading"
		case .failed(let message):
			"ASCII media failed: \(message)"
		case .ready(let frames):
			if frames.count > 1 {
				"ASCII video with \(frames.count) preloaded frames"
			} else {
				"ASCII image"
			}
		}
	}

	private func loadMedia() async {
		currentFrameIndex = 0
		phase = .loading

		do {
			let frames = try await AsciiMediaLoader.loadFrames(
				from: source,
				configuration: configuration.conversionConfiguration
			)
			guard !Task.isCancelled else { return }
			phase = .ready(frames)
		} catch {
			guard !Task.isCancelled else { return }
			phase = .failed(error.localizedDescription)
		}
	}

	private func runPlayback() async {
		guard case .ready(let frames) = phase else { return }
		guard frames.count > 1, !reduceMotion else {
			currentFrameIndex = 0
			return
		}

		currentFrameIndex = 0
		let milliseconds = max(16, Int(1_000 / configuration.frameRate))
		while !Task.isCancelled {
			try? await Task.sleep(for: .milliseconds(milliseconds))
			guard !Task.isCancelled else { return }
			currentFrameIndex = (currentFrameIndex + 1) % frames.count
		}
	}
}

extension AsciiMediaView {
	func asciiColumns(_ columns: Int) -> Self {
		var copy = self
		copy.configuration.columns = max(1, columns)
		return copy
	}

	func asciiMaxRows(_ rows: Int?) -> Self {
		var copy = self
		copy.configuration.maxRows = rows.map { max(1, $0) }
		return copy
	}

	func asciiScaleMode(_ scaleMode: ScaleMode) -> Self {
		var copy = self
		copy.configuration.scaleMode = scaleMode
		return copy
	}

	func asciiPreservesAspectRatio(_ preservesAspectRatio: Bool = true) -> Self {
		var copy = self
		copy.configuration.preservesAspectRatio = preservesAspectRatio
		return copy
	}

	func asciiCharacters(_ characters: String) -> Self {
		var copy = self
		copy.configuration.characters = characters
		return copy
	}

	func asciiGlyphRamp(_ characters: String) -> Self {
		asciiCharacters(characters)
	}

	func asciiFrameRate(_ frameRate: Double) -> Self {
		var copy = self
		copy.configuration.frameRate = min(60, max(1, frameRate))
		return copy
	}

	func asciiMaxVideoFrames(_ frameCount: Int) -> Self {
		var copy = self
		copy.configuration.maxVideoFrames = max(1, frameCount)
		return copy
	}

	func asciiColor(_ color: Color) -> Self {
		var copy = self
		copy.configuration.foreground = color
		return copy
	}

	func asciiFontSize(_ fontSize: CGFloat) -> Self {
		var copy = self
		copy.configuration.fontSize = max(1, fontSize)
		return copy
	}

	func asciiBackground(_ color: Color) -> Self {
		var copy = self
		copy.configuration.background = color
		return copy
	}
}

private enum AsciiMediaPhase {
	case idle
	case loading
	case ready([AsciiMediaFrame])
	case failed(String)
}

private struct AsciiMediaConfiguration {
	var columns = 198
	var maxRows: Int?
	var scaleMode: AsciiMediaScaleMode = .fill
	var preservesAspectRatio = true
	var characters = AsciiMediaView.defaultCharacters
	var frameRate = 8.0
	var maxVideoFrames = 180
	var foreground = Color.accent
	var background = Color.clear
	var fontSize: CGFloat = 8
	var placeholderHeight: CGFloat = 360

	var sanitizedCharacters: String {
		let characters = characters.filter { character in
			!character.isNewline && !character.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
		}
		return characters.isEmpty ? asciiMediaDefaultCharacters : String(characters)
	}

	var cellSize: CGSize {
		CGSize(width: fontSize * 0.62, height: fontSize * 1.08)
	}

	var conversionConfiguration: AsciiConversionConfiguration {
		AsciiConversionConfiguration(
			columns: columns,
			maxRows: maxRows,
			scaleMode: scaleMode,
			preservesAspectRatio: preservesAspectRatio,
			characters: Array(sanitizedCharacters),
			frameRate: frameRate,
			maxVideoFrames: maxVideoFrames,
			cellSize: cellSize
		)
	}
}

private struct AsciiConversionConfiguration {
	let columns: Int
	let maxRows: Int?
	let scaleMode: AsciiMediaScaleMode
	let preservesAspectRatio: Bool
	let characters: [Character]
	let frameRate: Double
	let maxVideoFrames: Int
	let cellSize: CGSize
}

private struct AsciiMediaFrame {
	let rows: [String]
	let columns: Int
	let cellSize: CGSize

	var pixelSize: CGSize {
		CGSize(width: CGFloat(columns) * cellSize.width, height: CGFloat(rows.count) * cellSize.height)
	}

	var displayAspectRatio: CGFloat {
		guard pixelSize.height > 0 else { return 1 }
		return pixelSize.width / pixelSize.height
	}
}

private struct AsciiMediaCanvas: View {
	let frame: AsciiMediaFrame
	let configuration: AsciiMediaConfiguration

	var body: some View {
		Canvas { context, size in
			context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(configuration.background))
			drawFrame(in: &context, size: size)
		}
		.frame(
			idealWidth: configuration.scaleMode == .fit ? frame.pixelSize.width : nil,
			idealHeight: configuration.scaleMode == .fit ? frame.pixelSize.height : nil
		)
	}

	private func drawFrame(in context: inout GraphicsContext, size: CGSize) {
		let baseSize = frame.pixelSize
		guard baseSize.width > 0, baseSize.height > 0, size.width > 0, size.height > 0 else { return }

		let widthScale = size.width / baseSize.width
		let heightScale = size.height / baseSize.height
		let scale = configuration.scaleMode == .fill ? max(widthScale, heightScale) : min(widthScale, heightScale)
		let drawSize = CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
		let origin = CGPoint(
			x: (size.width - drawSize.width) / 2,
			y: (size.height - drawSize.height) / 2
		)

		context.translateBy(x: origin.x, y: origin.y)
		context.scaleBy(x: scale, y: scale)

		let font = Font.monocraft(size: configuration.fontSize)
		for (index, row) in frame.rows.enumerated() {
			let point = CGPoint(x: 0, y: CGFloat(index) * frame.cellSize.height)
			let text = Text(row)
				.font(font)
				.foregroundStyle(configuration.foreground)
			context.draw(text, at: point, anchor: .topLeading)
		}
	}
}

private struct AsciiMediaStatusView: View {
	let title: String
	let message: String
	let isLoading: Bool
	let configuration: AsciiMediaConfiguration

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 6) {
				Text(title)
					.font(.monocraft(relativeTo: .caption, weight: .semibold))

				if isLoading {
					TerminalGlyphLoader(
						style: .blocks,
						textStyle: .caption,
						weight: .bold,
						color: .terminalWarning
					)
				}
			}
			.foregroundStyle(isLoading ? Color.terminalWarning : Color.terminalDanger)

			Text(message)
				.font(.monocraft(relativeTo: .caption2))
				.foregroundStyle(Color.terminalMutedText)
				.lineLimit(3)
		}
		.padding(12)
		.frame(maxWidth: .infinity, minHeight: configuration.placeholderHeight, alignment: .leading)
	}
}

private enum AsciiMediaLoader {
	static func loadFrames(
		from source: AsciiMediaView.Source,
		configuration: AsciiConversionConfiguration
	) async throws -> [AsciiMediaFrame] {
		let images: [CGImage]

		switch source {
		case .image(let image):
			images = [image]
		case .imageFile(let url):
			images = [try await loadImage(from: url)]
		case .remoteImage(let url):
			images = [try await loadRemoteImage(from: url)]
		case .videoFile(let url), .remoteVideo(let url):
			images = try await loadVideoFrames(from: url, configuration: configuration)
		#if canImport(UIKit)
			case .catalogVideo(let name):
				let url = try catalogVideoFileURL(named: name)
				images = try await loadVideoFrames(from: url, configuration: configuration)
			case .uiImage(let image):
				guard let cgImage = image.asciiNormalizedCGImage else {
					throw AsciiMediaError.imageDecodeFailed
				}
				images = [cgImage]
		#endif
		}

		let task: Task<[AsciiMediaFrame], Error> = Task.detached(priority: .userInitiated) {
			try images.map { image in
				try Task.checkCancellation()
				return try AsciiRasterizer.rasterize(image, configuration: configuration)
			}
		}

		return try await withTaskCancellationHandler {
			try await task.value
		} onCancel: {
			task.cancel()
		}
	}

	#if canImport(UIKit)
		private static func catalogVideoFileURL(named name: String) throws -> URL {
			guard let asset = NSDataAsset(name: name) else {
				throw AsciiMediaError.videoDecodeFailed
			}
			let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			let fileURL = dir.appendingPathComponent("ascii-catalog-video-\(name).mp4", isDirectory: false)
			if !FileManager.default.fileExists(atPath: fileURL.path) {
				try asset.data.write(to: fileURL, options: .atomic)
			}
			return fileURL
		}
	#endif

	private static func loadImage(from url: URL) async throws -> CGImage {
		let task: Task<Data, Error> = Task.detached(priority: .userInitiated) {
			try Data(contentsOf: url)
		}
		let data = try await withTaskCancellationHandler {
			try await task.value
		} onCancel: {
			task.cancel()
		}
		return try decodeImage(from: data)
	}

	private static func loadRemoteImage(from url: URL) async throws -> CGImage {
		let (data, response) = try await URLSession.shared.data(from: url)
		if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
			throw AsciiMediaError.remoteStatus(httpResponse.statusCode)
		}
		return try decodeImage(from: data)
	}

	private static func decodeImage(from data: Data) throws -> CGImage {
		#if canImport(UIKit)
			guard let image = UIImage(data: data), let cgImage = image.asciiNormalizedCGImage else {
				throw AsciiMediaError.imageDecodeFailed
			}
			return cgImage
		#else
			guard
				let source = CGImageSourceCreateWithData(data as CFData, nil),
				let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
			else {
				throw AsciiMediaError.imageDecodeFailed
			}
			return image
		#endif
	}

	private static func loadVideoFrames(
		from url: URL,
		configuration: AsciiConversionConfiguration
	) async throws -> [CGImage] {
		let asset = AVURLAsset(url: url)
		let duration = try await asset.load(.duration)
		let seconds = CMTimeGetSeconds(duration)
		guard seconds.isFinite, seconds > 0 else {
			throw AsciiMediaError.videoDecodeFailed
		}

		let requestedFrames = max(1, Int(ceil(seconds * configuration.frameRate)))
		let frameCount = min(requestedFrames, configuration.maxVideoFrames)
		let frameStep = seconds / Double(frameCount)
		let times = (0..<frameCount).map { index in
			CMTime(seconds: Double(index) * frameStep, preferredTimescale: 600)
		}

		let task: Task<[CGImage], Error> = Task.detached(priority: .userInitiated) {
			let generator = AVAssetImageGenerator(asset: asset)
			generator.appliesPreferredTrackTransform = true
			generator.requestedTimeToleranceBefore = CMTime(seconds: frameStep / 2, preferredTimescale: 600)
			generator.requestedTimeToleranceAfter = CMTime(seconds: frameStep / 2, preferredTimescale: 600)

			return try await generateImages(with: generator, at: times)
		}

		return try await withTaskCancellationHandler {
			try await task.value
		} onCancel: {
			task.cancel()
		}
	}

	private static func generateImages(
		with generator: AVAssetImageGenerator,
		at times: [CMTime]
	) async throws -> [CGImage] {
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				let requestedTimes = times.map { NSValue(time: $0) }
				let timeIndexes = Dictionary(
					uniqueKeysWithValues: times.enumerated().map { index, time in
						(CMTimeGetSeconds(time), index)
					}
				)
				let lock = NSLock()
				var remaining = times.count
				var frames = [CGImage?](repeating: nil, count: times.count)
				var firstError: Error?

				generator.generateCGImagesAsynchronously(forTimes: requestedTimes) {
					requestedTime, image, _, result, error in
					lock.lock()
					defer { lock.unlock() }

					if let index = timeIndexes[CMTimeGetSeconds(requestedTime)] {
						switch result {
						case .succeeded:
							frames[index] = image
						case .failed:
							firstError = firstError ?? error ?? AsciiMediaError.videoDecodeFailed
						case .cancelled:
							firstError = firstError ?? CancellationError()
						@unknown default:
							firstError = firstError ?? AsciiMediaError.videoDecodeFailed
						}
					}

					remaining -= 1
					guard remaining == 0 else { return }

					if let firstError {
						continuation.resume(throwing: firstError)
						return
					}

					let decodedFrames = frames.compactMap { $0 }
					guard !decodedFrames.isEmpty else {
						continuation.resume(throwing: AsciiMediaError.videoDecodeFailed)
						return
					}

					continuation.resume(returning: decodedFrames)
				}
			}
		} onCancel: {
			generator.cancelAllCGImageGeneration()
		}
	}
}

private enum AsciiRasterizer {
	nonisolated static func rasterize(
		_ image: CGImage,
		configuration: AsciiConversionConfiguration
	) throws -> AsciiMediaFrame {
		let targetSize = targetGridSize(for: image, configuration: configuration)
		let pixelCount = targetSize.columns * targetSize.rows
		var pixels = [UInt8](repeating: 255, count: pixelCount)

		try pixels.withUnsafeMutableBytes { buffer in
			guard
				let baseAddress = buffer.baseAddress,
				let context = CGContext(
					data: baseAddress,
					width: targetSize.columns,
					height: targetSize.rows,
					bitsPerComponent: 8,
					bytesPerRow: targetSize.columns,
					space: CGColorSpaceCreateDeviceGray(),
					bitmapInfo: CGImageAlphaInfo.none.rawValue
				)
			else {
				throw AsciiMediaError.rasterizationFailed
			}

			let rect = CGRect(
				x: 0,
				y: 0,
				width: CGFloat(targetSize.columns),
				height: CGFloat(targetSize.rows)
			)
			context.setFillColor(gray: 1, alpha: 1)
			context.fill(rect)
			context.interpolationQuality = .medium
			context.draw(image, in: rect)
		}

		let rows = buildRows(
			from: pixels,
			columns: targetSize.columns,
			rows: targetSize.rows,
			characters: configuration.characters
		)

		return AsciiMediaFrame(
			rows: rows,
			columns: targetSize.columns,
			cellSize: configuration.cellSize
		)
	}

	nonisolated private static func targetGridSize(
		for image: CGImage,
		configuration: AsciiConversionConfiguration
	) -> (columns: Int, rows: Int) {
		let sourceAspectRatio = Double(image.height) / Double(max(1, image.width))
		let cellAspectRatio = Double(configuration.cellSize.width / configuration.cellSize.height)

		var columns = max(1, configuration.columns)
		var rows: Int

		if configuration.preservesAspectRatio {
			rows = max(1, Int((Double(columns) * sourceAspectRatio * cellAspectRatio).rounded()))
		} else {
			rows = configuration.maxRows ?? columns
		}

		if let maxRows = configuration.maxRows {
			let clampedMaxRows = max(1, maxRows)
			if configuration.preservesAspectRatio, configuration.scaleMode == .fit, rows > clampedMaxRows {
				rows = clampedMaxRows
				let adjustedColumns = Double(rows) / max(0.01, sourceAspectRatio * cellAspectRatio)
				columns = max(1, Int(adjustedColumns.rounded()))
			} else {
				rows = min(rows, clampedMaxRows)
			}
		}

		return (columns, max(1, rows))
	}

	nonisolated private static func buildRows(
		from pixels: [UInt8],
		columns: Int,
		rows: Int,
		characters: [Character]
	) -> [String] {
		let ramp = characters
		let maxIndex = max(0, ramp.count - 1)

		return (0..<rows).map { row in
			var line = ""
			line.reserveCapacity(columns)

			for column in 0..<columns {
				let luminance = Double(pixels[row * columns + column]) / 255
				let index = Int(((1 - luminance) * Double(maxIndex)).rounded())
				line.append(ramp[min(max(index, 0), maxIndex)])
			}

			return line
		}
	}
}

private enum AsciiMediaError: LocalizedError {
	case imageDecodeFailed
	case videoDecodeFailed
	case rasterizationFailed
	case remoteStatus(Int)

	var errorDescription: String? {
		switch self {
		case .imageDecodeFailed:
			"could not decode image source"
		case .videoDecodeFailed:
			"could not decode video source"
		case .rasterizationFailed:
			"could not rasterize media into ASCII"
		case .remoteStatus(let statusCode):
			"remote source returned HTTP \(statusCode)"
		}
	}
}

#if canImport(UIKit)
	private extension UIImage {
		var asciiNormalizedCGImage: CGImage? {
			guard imageOrientation != .up else {
				return cgImage
			}

			let format = UIGraphicsImageRendererFormat.default()
			format.scale = scale
			let renderer = UIGraphicsImageRenderer(size: size, format: format)
			return renderer.image { _ in
				draw(in: CGRect(origin: .zero, size: size))
			}.cgImage
		}
	}
	#Preview {
		AsciiMediaView(catalogVideoNamed: "mageOpening")
			.asciiColumns(48)
	}
#endif

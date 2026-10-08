//
//  DreamLiteOnDeviceGenerator.swift
//  magoSanduiche
//

import CoreGraphics
import CoreML
import Foundation

nonisolated enum DreamLiteError: Error, LocalizedError, Equatable {
	case emptyPrompt
	/// No bundled or installed models and no `DREAMLITE_MODEL_BASE_URL` to download them from.
	case modelsUnavailable
	case invalidManifest(String)
	case downloadFailed(Int)
	case integrityCheckFailed(String)
	case tokenizerUnavailable
	case missingOutput(String)
	/// A newer scene prompt started before this one finished.
	case superseded

	var errorDescription: String? {
		switch self {
		case .emptyPrompt:
			"DreamLite needs a non-empty prompt"
		case .modelsUnavailable:
			"DreamLite models are not installed and DREAMLITE_MODEL_BASE_URL is not set"
		case .invalidManifest(let reason):
			"DreamLite model manifest is invalid: \(reason)"
		case .downloadFailed(let status):
			"DreamLite model download returned HTTP \(status)"
		case .integrityCheckFailed(let path):
			"DreamLite model file failed its size or SHA-256 check: \(path)"
		case .tokenizerUnavailable:
			"DreamLite tokenizer resources are missing from the app bundle"
		case .missingOutput(let name):
			"DreamLite Core ML model returned no \(name)"
		case .superseded:
			"A newer scene replaced this DreamLite generation"
		}
	}

	var analyticsKind: String {
		switch self {
		case .emptyPrompt: "dreamlite_empty_prompt"
		case .modelsUnavailable: "dreamlite_models_unavailable"
		case .invalidManifest: "dreamlite_invalid_manifest"
		case .downloadFailed: "dreamlite_download_failed"
		case .integrityCheckFailed: "dreamlite_integrity_check_failed"
		case .tokenizerUnavailable: "dreamlite_tokenizer_unavailable"
		case .missingOutput: "dreamlite_missing_output"
		case .superseded: "dreamlite_superseded"
		}
	}
}

nonisolated protocol DreamLiteImageGenerating: Sendable {
	func generateImage(prompt: String) async throws -> CGImage
	func generateImage(prompt: String, progress: SceneIllustrationProgress) async throws -> CGImage
}

extension DreamLiteImageGenerating {
	func generateImage(prompt: String, progress: SceneIllustrationProgress) async throws -> CGImage {
		_ = progress
		return try await generateImage(prompt: prompt)
	}
}

/// One share per pipeline stage: model load, each text chunk, the painter, each denoising step, then the decode.
nonisolated struct DreamLiteRunProgress: Equatable, Sendable {
	private var completed = 0
	let total: Int

	init(textChunks: Int, steps: Int) {
		total = 1 + max(0, textChunks) + 1 + max(1, steps) + 1
	}

	var fraction: Double {
		guard total > 0 else { return 1 }
		return Double(completed) / Double(total)
	}

	mutating func advance() -> Double {
		completed = min(total, completed + 1)
		return fraction
	}
}

/// Runs `carlofkl/DreamLite-mobile` text-to-image on device with Core ML:
/// Qwen3-VL text encoder chunks, a few flow-matching UNet steps, then the TAESDXL decoder.
actor DreamLiteOnDeviceGenerator: DreamLiteImageGenerating {
	static let shared = DreamLiteOnDeviceGenerator()

	nonisolated struct Configuration: Sendable {
		/// `nil` uses the manifest's `default_steps` (4, what the mobile distillation is tuned for).
		var steps: Int?
		/// `nil` draws a fresh seed for every scene.
		var seed: UInt64?
		var computeUnits: MLComputeUnits = .cpuAndGPU
		var tokenizerBundle: Bundle = .main
	}

	private let store: DreamLiteModelStore
	private let configuration: Configuration
	private var tokenizer: DreamLiteTokenizer?
	private var resident: (models: DreamLiteCompiledModels, unet: MLModel, decoder: MLModel)?
	private var latestTicket = 0
	private var tail: Task<Void, Never>?

	init(store: DreamLiteModelStore = DreamLiteModelStore(), configuration: Configuration = Configuration()) {
		self.store = store
		self.configuration = configuration
	}

	/// Generations run one at a time; a newer prompt stops older ones at their next step boundary.
	func generateImage(prompt: String) async throws -> CGImage {
		try await generateImage(prompt: prompt, progress: .ignored)
	}

	func generateImage(prompt: String, progress: SceneIllustrationProgress) async throws -> CGImage {
		let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { throw DreamLiteError.emptyPrompt }

		latestTicket += 1
		let ticket = latestTicket
		let previous = tail
		let work = Task {
			await previous?.value
			return try await self.run(trimmed, ticket: ticket, progress: progress)
		}
		tail = Task { _ = try? await work.value }
		return try await withTaskCancellationHandler {
			try await work.value
		} onCancel: {
			work.cancel()
		}
	}

	/// Drops the resident UNet and decoder (for example on a memory warning).
	func unloadModels() {
		resident = nil
	}

	private func checkpoint(_ ticket: Int) throws {
		try Task.checkCancellation()
		guard ticket == latestTicket else { throw DreamLiteError.superseded }
	}

	private func run(_ prompt: String, ticket: Int, progress: SceneIllustrationProgress) async throws -> CGImage {
		try checkpoint(ticket)
		let models = try await store.models()
		let manifest = models.manifest
		let window = try promptEncoder(for: manifest).window(for: prompt)
		let side = manifest.latentSize
		let schedule = DreamLiteFlowMatchSchedule(
			steps: configuration.steps ?? manifest.defaultSteps,
			latentHeight: side,
			latentWidth: side,
			configuration: manifest.scheduler
		)
		var meter = DreamLiteRunProgress(textChunks: models.textEncoderURLs.count, steps: schedule.stepCount)
		progress.update(meter.advance())

		try checkpoint(ticket)
		let embeddings = try await encodeText(
			window.tokenIDs,
			models: models,
			ticket: ticket,
			meter: &meter,
			progress: progress
		)
		let mask = MLShapedArray<Float32>(
			scalars: (0..<manifest.promptEmbeddingCount).map { $0 < window.validEmbeddingCount ? 1 : 0 },
			shape: [1, manifest.promptEmbeddingCount]
		)

		let (unet, decoder) = try await residentModels(models)
		progress.update(meter.advance())
		let latentShape = [1, manifest.latentChannels, side, side]
		var noise = DreamLiteNoise(seed: configuration.seed ?? UInt64.random(in: .min ... .max))
		var latents = noise.gaussian(count: latentShape.reduce(1, *))
		for index in 0..<schedule.stepCount {
			try checkpoint(ticket)
			let input = try MLDictionaryFeatureProvider(dictionary: [
				"latents": MLMultiArray(MLShapedArray<Float32>(scalars: latents, shape: latentShape)),
				"timestep": MLMultiArray(MLShapedArray<Float32>(scalars: [schedule.timestep(at: index)], shape: [1])),
				"encoder_hidden_states": MLMultiArray(embeddings),
				"encoder_attention_mask": MLMultiArray(mask),
			])
			let velocity = try await Self.output("noise_pred", of: unet.prediction(from: input))
			schedule.step(&latents, velocity: velocity.scalars, at: index)
			progress.update(meter.advance())
		}

		try checkpoint(ticket)
		let decoded = try await Self.output(
			"image",
			of: decoder.prediction(from: MLDictionaryFeatureProvider(dictionary: [
				"latents": MLMultiArray(MLShapedArray<Float32>(scalars: latents, shape: latentShape)),
			]))
		)
		let shape = decoded.shape
		guard shape.count == 4, shape[1] == 3 else { throw DreamLiteError.missingOutput("image") }
		let image = try DreamLiteImageEncoding.cgImage(planarRGB: decoded.scalars, width: shape[3], height: shape[2])
		progress.update(meter.advance())
		return image
	}

	/// Chunks are loaded one at a time so the ~1.7B-parameter text encoder never sits in memory at once.
	private func encodeText(
		_ tokenIDs: [Int32],
		models: DreamLiteCompiledModels,
		ticket: Int,
		meter: inout DreamLiteRunProgress,
		progress: SceneIllustrationProgress
	) async throws -> MLShapedArray<Float32> {
		var hidden: MLShapedArray<Float32>?
		for (index, url) in models.textEncoderURLs.enumerated() {
			try checkpoint(ticket)
			let model = try await MLModel.load(contentsOf: url, configuration: modelConfiguration())
			let input: MLMultiArray =
				if let hidden {
					MLMultiArray(hidden)
				} else {
					MLMultiArray(MLShapedArray<Int32>(scalars: tokenIDs, shape: [1, tokenIDs.count]))
				}
			let name = index == 0 ? "input_ids" : "input_hidden_states"
			let output = try await model.prediction(from: MLDictionaryFeatureProvider(dictionary: [name: input]))
			hidden = try Self.output("hidden_states", of: output)
			progress.update(meter.advance())
		}
		guard let hidden else { throw DreamLiteError.missingOutput("hidden_states") }
		return hidden
	}

	private func residentModels(_ models: DreamLiteCompiledModels) async throws -> (MLModel, MLModel) {
		if let resident, resident.models == models {
			return (resident.unet, resident.decoder)
		}
		resident = nil
		let unet = try await MLModel.load(contentsOf: models.unetURL, configuration: modelConfiguration())
		let decoder = try await MLModel.load(contentsOf: models.decoderURL, configuration: modelConfiguration())
		resident = (models, unet, decoder)
		return (unet, decoder)
	}

	private func modelConfiguration() -> MLModelConfiguration {
		let modelConfiguration = MLModelConfiguration()
		modelConfiguration.computeUnits = configuration.computeUnits
		return modelConfiguration
	}

	private func promptEncoder(for manifest: DreamLiteManifest) throws -> DreamLitePromptEncoder {
		let tokenizer = try self.tokenizer ?? DreamLiteTokenizer.bundled(in: configuration.tokenizerBundle)
		self.tokenizer = tokenizer
		return DreamLitePromptEncoder(
			tokenizer: tokenizer,
			sequenceLength: manifest.textSequenceLength,
			dropTokenCount: manifest.dropTokenCount,
			padTokenID: manifest.padTokenID
		)
	}

	/// Copies an output into a contiguous float32 array whatever its storage type or strides.
	private static func output(_ name: String, of features: any MLFeatureProvider) throws -> MLShapedArray<Float32> {
		guard let array = features.featureValue(for: name)?.multiArrayValue else {
			throw DreamLiteError.missingOutput(name)
		}
		return MLShapedArray<Float32>(converting: array)
	}
}

nonisolated enum DreamLiteImageEncoding {
	/// Planar RGB in [0, 1] (`1×3×H×W`) to interleaved RGBA8, rounding like diffusers' `numpy_to_pil`.
	static func rgbaBytes(planarRGB: [Float], width: Int, height: Int) -> [UInt8] {
		let plane = width * height
		precondition(planarRGB.count == plane * 3)
		var bytes = [UInt8](repeating: 255, count: plane * 4)
		for channel in 0..<3 {
			let offset = channel * plane
			for pixel in 0..<plane {
				let value = min(max(planarRGB[offset + pixel], 0), 1)
				bytes[pixel * 4 + channel] = UInt8((value * 255).rounded())
			}
		}
		return bytes
	}

	static func cgImage(planarRGB: [Float], width: Int, height: Int) throws -> CGImage {
		let bytes = rgbaBytes(planarRGB: planarRGB, width: width, height: height)
		guard
			let provider = CGDataProvider(data: Data(bytes) as CFData),
			let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
			let image = CGImage(
				width: width,
				height: height,
				bitsPerComponent: 8,
				bitsPerPixel: 32,
				bytesPerRow: width * 4,
				space: colorSpace,
				bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
				provider: provider,
				decode: nil,
				shouldInterpolate: true,
				intent: .defaultIntent
			)
		else {
			throw SceneMediaError.noImage
		}
		return image
	}
}

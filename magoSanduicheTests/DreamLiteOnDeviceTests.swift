//
//  DreamLiteOnDeviceTests.swift
//  magoSanduicheTests
//

import CoreGraphics
import CryptoKit
import Foundation
import Testing
@testable import magoSanduiche

/// `Fixtures/dreamlite_tokenizer_vectors.json`, written by `tools/dreamlite-coreml/tokenizer_vectors.py`
/// from the Hugging Face tokenizer that `DreamLiteMobilePipeline` uses.
private struct TokenizerFixture: Decodable {
	struct Case: Decodable {
		var prompt: String
		var rawIDs: [Int]
		var windowIDs: [Int]
		var validEmbeddings: Int

		enum CodingKeys: String, CodingKey {
			case prompt
			case rawIDs = "raw_ids"
			case windowIDs = "window_ids"
			case validEmbeddings = "valid_embeddings"
		}
	}

	var sequenceLength: Int
	var cases: [Case]

	enum CodingKeys: String, CodingKey {
		case sequenceLength = "sequence_length"
		case cases
	}

	static func load() throws -> TokenizerFixture {
		let url = try #require(
			Bundle(for: FixtureBundleToken.self).url(forResource: "dreamlite_tokenizer_vectors", withExtension: "json")
		)
		return try JSONDecoder().decode(TokenizerFixture.self, from: Data(contentsOf: url))
	}
}

private final class FixtureBundleToken {}

struct DreamLiteTokenizerTests {
	@Test func encodesLikeTheHuggingFaceTokenizer() throws {
		let fixture = try TokenizerFixture.load()
		let tokenizer = try DreamLiteTokenizer.bundled(in: .main)
		#expect(fixture.cases.count >= 10)
		for testCase in fixture.cases {
			#expect(tokenizer.encode(testCase.prompt) == testCase.rawIDs, "\(testCase.prompt)")
		}
	}

	@Test func buildsThePipelineTextWindow() throws {
		let fixture = try TokenizerFixture.load()
		let encoder = DreamLitePromptEncoder(tokenizer: try DreamLiteTokenizer.bundled(in: .main))
		#expect(encoder.sequenceLength == fixture.sequenceLength)
		for testCase in fixture.cases {
			let window = encoder.window(for: testCase.prompt)
			#expect(window.tokenIDs.map(Int.init) == testCase.windowIDs, "\(testCase.prompt)")
			#expect(window.validEmbeddingCount == testCase.validEmbeddings, "\(testCase.prompt)")
		}
	}

	@Test func longPromptsKeepTheAssistantSuffix() throws {
		let tokenizer = try DreamLiteTokenizer.bundled(in: .main)
		let encoder = DreamLitePromptEncoder(tokenizer: tokenizer)
		let window = encoder.window(for: String(repeating: "torchlit obsidian stairs ", count: 200))
		let suffix = tokenizer.encode(DreamLitePromptEncoder.assistantSuffix).map(Int32.init)

		#expect(window.tokenIDs.count == encoder.sequenceLength)
		#expect(Array(window.tokenIDs.suffix(suffix.count)) == suffix)
		#expect(window.validEmbeddingCount == encoder.sequenceLength - encoder.dropTokenCount)
	}
}

struct DreamLiteSamplingTests {
	/// `FlowMatchEulerDiscreteScheduler.set_timesteps` as called by `DreamLiteMobilePipeline` at 1024×1024.
	@Test func fourStepSigmasMatchDiffusers() {
		let schedule = DreamLiteFlowMatchSchedule(steps: 4, latentHeight: 128, latentWidth: 128)
		let diffusers = [1.0, 0.9045307636260986, 0.7595109343528748, 0.5128441452980042, 0.0]

		#expect(schedule.stepCount == 4)
		for (sigma, expected) in zip(schedule.sigmas, diffusers) {
			#expect(abs(sigma - expected) < 1e-6)
		}
		#expect(abs(schedule.timestep(at: 3) - 512.8441) < 1e-3)
	}

	@Test func eightAndOneStepSchedulesMatchDiffusers() {
		let eight = DreamLiteFlowMatchSchedule(steps: 8, latentHeight: 128, latentWidth: 128)
		let diffusers = [
			1.0, 0.956723690032959, 0.9045307636260986, 0.8403487801551819, 0.7595109343528748,
			0.654566764831543, 0.5128441452980042, 0.31090107560157776, 0.0,
		]
		#expect(zip(eight.sigmas, diffusers).allSatisfy { abs($0 - $1) < 1e-6 })
		#expect(DreamLiteFlowMatchSchedule(steps: 1, latentHeight: 128, latentWidth: 128).sigmas == [1, 0])
	}

	@Test func eulerStepMovesAlongTheVelocity() {
		let schedule = DreamLiteFlowMatchSchedule(steps: 4, latentHeight: 128, latentWidth: 128)
		var latents: [Float] = [1, 2]
		schedule.step(&latents, velocity: [10, -10], at: 0)
		let delta = Float(schedule.sigmas[1] - schedule.sigmas[0])

		#expect(abs(latents[0] - (1 + 10 * delta)) < 1e-6)
		#expect(abs(latents[1] - (2 - 10 * delta)) < 1e-6)
	}

	@Test func seededNoiseIsReproducibleStandardNormal() {
		var first = DreamLiteNoise(seed: 42)
		var second = DreamLiteNoise(seed: 42)
		var other = DreamLiteNoise(seed: 43)
		let values = first.gaussian(count: 4 * 128 * 128)
		let mean = values.reduce(0, +) / Float(values.count)
		let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(values.count)

		#expect(values == second.gaussian(count: values.count))
		#expect(values != other.gaussian(count: values.count))
		#expect(abs(mean) < 0.02)
		#expect(abs(variance - 1) < 0.03)
	}
}

struct DreamLiteManifestTests {
	@Test func decodesTheConverterManifest() throws {
		let manifest = try DreamLiteManifest.decode(Data(Self.manifestJSON(files: []).utf8))

		#expect(manifest.packages == [
			"DreamLiteTextEncoder0.mlpackage", "DreamLiteTextEncoder1.mlpackage",
			"DreamLiteUNet.mlpackage", "DreamLiteDecoder.mlpackage",
		])
		#expect(manifest.promptEmbeddingCount == 222)
		#expect(manifest.scheduler == .dreamLiteMobile)
		#expect(DreamLiteManifest.modelName(manifest.unet) == "DreamLiteUNet")
	}

	@Test func rejectsPathsThatEscapeTheModelFolder() {
		for path in ["../escape.bin", "/etc/hosts", "a//b", "a/./b", "a\\b", ""] {
			#expect(!DreamLiteManifest.isSafeRelativePath(path), "\(path)")
		}
		#expect(DreamLiteManifest.isSafeRelativePath("DreamLiteUNet.mlpackage/Data/com.apple.CoreML/weights/weight.bin"))

		let json = Self.manifestJSON(files: [#"{"path": "../../Library/evil", "size": 1, "sha256": "\#(String(repeating: "0", count: 64))"}"#])
		#expect(throws: DreamLiteError.self) {
			try DreamLiteManifest.decode(Data(json.utf8))
		}
	}

	@Test func rejectsUnknownFormats() {
		let json = Self.manifestJSON(files: []).replacingOccurrences(of: #""format": 1"#, with: #""format": 2"#)
		#expect(throws: DreamLiteError.invalidManifest("unsupported format 2")) {
			try DreamLiteManifest.decode(Data(json.utf8))
		}
	}

	static func manifestJSON(files: [String]) -> String {
		"""
		{
		  "format": 1, "model_id": "carlofkl/DreamLite-mobile", "license": "CC-BY-NC-4.0",
		  "image_size": 1024, "latent_size": 128, "latent_channels": 4,
		  "text_sequence_length": 256, "drop_token_count": 34, "pad_token_id": 151643, "hidden_size": 2048,
		  "default_steps": 4,
		  "scheduler": {"num_train_timesteps": 1000, "base_image_seq_len": 256, "max_image_seq_len": 4096, "base_shift": 0.5, "max_shift": 1.15},
		  "text_encoder": ["DreamLiteTextEncoder0.mlpackage", "DreamLiteTextEncoder1.mlpackage"],
		  "unet": "DreamLiteUNet.mlpackage", "decoder": "DreamLiteDecoder.mlpackage",
		  "weight_bits": {"text_encoder": 8, "unet": 8, "decoder": 16},
		  "files": [\(files.joined(separator: ", "))]
		}
		"""
	}
}

struct DreamLiteModelStoreTests {
	private static let baseURL = URL(string: "https://models.test/dreamlite")!

	@Test func downloadsVerifiesCompilesAndReusesTheModels() async throws {
		let sandbox = try Sandbox()
		let remote = try sandbox.remote()
		let downloader = FolderDownloader(root: remote.folder, baseURL: Self.baseURL)
		let install = sandbox.url("Support/Models")
		let store = DreamLiteModelStore(
			configuration: .init(bundle: sandbox.emptyBundle, installDirectory: install, remoteBaseURL: Self.baseURL),
			downloader: downloader,
			compile: fakeCompile
		)

		async let first = store.models()
		async let second = store.models()
		let (models, again) = try await (first, second)

		#expect(models == again)
		#expect(await downloader.requests.count == 1 + remote.fileCount)
		#expect(models.textEncoderURLs.map(\.lastPathComponent) == ["DreamLiteTextEncoder0.mlmodelc", "DreamLiteTextEncoder1.mlmodelc"])
		#expect(models.unetURL.lastPathComponent == "DreamLiteUNet.mlmodelc")
		#expect(FileManager.default.fileExists(atPath: install.appendingPathComponent(DreamLiteManifest.fileName).path))
		#expect(try FileManager.default.contentsOfDirectory(atPath: install.deletingLastPathComponent().path) == ["Models"])

		let relaunched = DreamLiteModelStore(
			configuration: .init(bundle: sandbox.emptyBundle, installDirectory: install, remoteBaseURL: nil),
			downloader: FolderDownloader(root: remote.folder, baseURL: Self.baseURL),
			compile: fakeCompile
		)
		#expect(try await relaunched.models() == models)
	}

	@Test func tamperedFilesFailTheIntegrityCheckAndLeaveNothingBehind() async throws {
		let sandbox = try Sandbox()
		let remote = try sandbox.remote(tampering: "DreamLiteUNet.mlpackage/Data/com.apple.CoreML/weights/weight.bin")
		let install = sandbox.url("Support/Models")
		let store = DreamLiteModelStore(
			configuration: .init(bundle: sandbox.emptyBundle, installDirectory: install, remoteBaseURL: Self.baseURL),
			downloader: FolderDownloader(root: remote.folder, baseURL: Self.baseURL),
			compile: fakeCompile
		)

		await #expect(throws: DreamLiteError.integrityCheckFailed("DreamLiteUNet.mlpackage/Data/com.apple.CoreML/weights/weight.bin")) {
			try await store.models()
		}
		#expect(!FileManager.default.fileExists(atPath: install.path))
		#expect(try FileManager.default.contentsOfDirectory(atPath: install.deletingLastPathComponent().path).isEmpty)
	}

	@Test func missingModelsWithoutABaseURLAreReported() async throws {
		let sandbox = try Sandbox()
		let store = DreamLiteModelStore(
			configuration: .init(bundle: sandbox.emptyBundle, installDirectory: sandbox.url("Support/Models"), remoteBaseURL: nil)
		)

		await #expect(throws: DreamLiteError.modelsUnavailable) {
			try await store.models()
		}
	}

	@Test func unsetBuildSettingsMeanNoBaseURL() {
		typealias Configuration = DreamLiteModelStore.Configuration
		#expect(Configuration.configuredURL("$(DREAMLITE_MODEL_BASE_URL)") == nil)
		#expect(Configuration.configuredURL("  ") == nil)
		#expect(Configuration.configuredURL(nil) == nil)
		#expect(Configuration.configuredURL("https://huggingface.co/me/DreamLiteCoreML/resolve/main")?.host == "huggingface.co")
		#expect(Configuration.fromInfoDictionary([Configuration.baseURLInfoKey: ""]).remoteBaseURL == nil)
	}

	@Test func remoteFileURLsKeepThePackageLayout() {
		let url = DreamLiteModelStore.remoteURL(for: "DreamLiteUNet.mlpackage/Manifest.json", under: Self.baseURL)
		#expect(url.absoluteString == "https://models.test/dreamlite/DreamLiteUNet.mlpackage/Manifest.json")
	}
}

struct DreamLiteOnDeviceGeneratorTests {
	@Test func blankPromptsNeverLoadModels() async throws {
		let sandbox = try Sandbox()
		let generator = DreamLiteOnDeviceGenerator(
			store: DreamLiteModelStore(
				configuration: .init(bundle: sandbox.emptyBundle, installDirectory: sandbox.url("Models"), remoteBaseURL: nil)
			)
		)

		await #expect(throws: DreamLiteError.emptyPrompt) {
			try await generator.generateImage(prompt: "  \n ")
		}
	}

	@Test func missingModelsSurfaceAsModelsUnavailable() async throws {
		let sandbox = try Sandbox()
		let generator = DreamLiteOnDeviceGenerator(
			store: DreamLiteModelStore(
				configuration: .init(bundle: sandbox.emptyBundle, installDirectory: sandbox.url("Models"), remoteBaseURL: nil)
			)
		)

		await #expect(throws: DreamLiteError.modelsUnavailable) {
			try await generator.generateImage(prompt: "Torchlit corridor")
		}
	}

	@Test func decodedPixelsBecomeAnOpaqueRGBAImage() throws {
		let bytes = DreamLiteImageEncoding.rgbaBytes(planarRGB: [0, 0.5, 1, -1, 2, 0.25], width: 2, height: 1)
		#expect(bytes == [0, 255, 255, 255, 128, 0, 64, 255])

		let image = try DreamLiteImageEncoding.cgImage(planarRGB: Array(repeating: 0.5, count: 3 * 4 * 2), width: 4, height: 2)
		#expect(image.width == 4)
		#expect(image.height == 2)
		#expect(image.bytesPerRow == 16)
	}
}

/// Copies `X.mlpackage` to a temporary `X.mlmodelc`, standing in for `MLModel.compileModel(at:)`.
private let fakeCompile: DreamLiteModelStore.Compiler = { package in
	let output = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString, isDirectory: true)
		.appendingPathComponent(package.deletingPathExtension().lastPathComponent + ".mlmodelc", isDirectory: true)
	try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
	try FileManager.default.copyItem(at: package, to: output)
	return output
}

private struct Sandbox {
	let root: URL
	let emptyBundle: Bundle

	init() throws {
		root = FileManager.default.temporaryDirectory.appendingPathComponent("DreamLiteTests-\(UUID().uuidString)", isDirectory: true)
		let bundleFolder = root.appendingPathComponent("Empty.bundle", isDirectory: true)
		try FileManager.default.createDirectory(at: bundleFolder, withIntermediateDirectories: true)
		emptyBundle = try #require(Bundle(url: bundleFolder))
	}

	func url(_ path: String) -> URL {
		root.appendingPathComponent(path)
	}

	/// A `convert.py`-shaped folder with tiny packages and a manifest that hashes them.
	func remote(tampering tampered: String? = nil) throws -> (folder: URL, fileCount: Int) {
		let folder = url("remote")
		let packages = ["DreamLiteTextEncoder0", "DreamLiteTextEncoder1", "DreamLiteUNet", "DreamLiteDecoder"]
		var entries: [String] = []
		for name in packages {
			for (path, contents) in [
				("\(name).mlpackage/Manifest.json", #"{"fileFormatVersion": "1.0.0"}"#),
				("\(name).mlpackage/Data/com.apple.CoreML/weights/weight.bin", "weights of \(name)"),
			] {
				let data = Data(contents.utf8)
				let file = folder.appendingPathComponent(path)
				try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
				try data.write(to: file)
				let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
				entries.append(#"{"path": "\#(path)", "size": \#(data.count), "sha256": "\#(digest)"}"#)
			}
		}
		let manifest = DreamLiteManifestTests.manifestJSON(files: entries)
		try Data(manifest.utf8).write(to: folder.appendingPathComponent(DreamLiteManifest.fileName))
		if let tampered {
			try Data("tampered".utf8).write(to: folder.appendingPathComponent(tampered))
		}
		return (folder, entries.count)
	}
}

private actor FolderDownloader: DreamLiteFileDownloading {
	let root: URL
	let baseURL: URL
	private(set) var requests: [URL] = []

	init(root: URL, baseURL: URL) {
		self.root = root
		self.baseURL = baseURL
	}

	private func local(_ url: URL) throws -> URL {
		let prefix = baseURL.absoluteString + "/"
		guard url.absoluteString.hasPrefix(prefix) else { throw DreamLiteError.downloadFailed(404) }
		return root.appendingPathComponent(String(url.absoluteString.dropFirst(prefix.count)))
	}

	func data(from url: URL) async throws -> Data {
		requests.append(url)
		return try Data(contentsOf: local(url))
	}

	func download(from url: URL) async throws -> URL {
		requests.append(url)
		let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.copyItem(at: local(url), to: copy)
		return copy
	}
}

//
//  DreamLiteModelStore.swift
//  magoSanduiche
//

import CoreML
import CryptoKit
import Foundation

#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

/// `DreamLiteManifest.json`, written by `tools/dreamlite-coreml/convert.py` next to the Core ML packages.
nonisolated struct DreamLiteManifest: Codable, Equatable, Sendable {
	static let fileName = "DreamLiteManifest.json"
	static let supportedFormat = 1

	struct File: Codable, Equatable, Sendable {
		var path: String
		var size: Int64
		var sha256: String
	}

	var format: Int
	var modelID: String
	var imageSize: Int
	var latentSize: Int
	var latentChannels: Int
	var textSequenceLength: Int
	var dropTokenCount: Int
	var padTokenID: Int
	var hiddenSize: Int
	var defaultSteps: Int
	var scheduler: DreamLiteFlowMatchSchedule.Configuration
	/// Text-encoder chunks, run in order.
	var textEncoder: [String]
	var unet: String
	var decoder: String
	var files: [File]

	enum CodingKeys: String, CodingKey {
		case format
		case modelID = "model_id"
		case imageSize = "image_size"
		case latentSize = "latent_size"
		case latentChannels = "latent_channels"
		case textSequenceLength = "text_sequence_length"
		case dropTokenCount = "drop_token_count"
		case padTokenID = "pad_token_id"
		case hiddenSize = "hidden_size"
		case defaultSteps = "default_steps"
		case scheduler
		case textEncoder = "text_encoder"
		case unet
		case decoder
		case files
	}

	static func decode(_ data: Data) throws -> DreamLiteManifest {
		let manifest: DreamLiteManifest
		do {
			manifest = try JSONDecoder().decode(DreamLiteManifest.self, from: data)
		} catch {
			throw DreamLiteError.invalidManifest(error.localizedDescription)
		}
		try manifest.validate()
		return manifest
	}

	/// Package names in pipeline order (text chunks, UNet, decoder).
	var packages: [String] { textEncoder + [unet, decoder] }

	/// Text-encoder outputs per prompt once the system prefix is dropped.
	var promptEmbeddingCount: Int { textSequenceLength - dropTokenCount }

	func validate() throws {
		guard format == Self.supportedFormat else {
			throw DreamLiteError.invalidManifest("unsupported format \(format)")
		}
		guard !textEncoder.isEmpty, textSequenceLength > dropTokenCount, latentSize > 0, latentChannels > 0 else {
			throw DreamLiteError.invalidManifest("inconsistent model shapes")
		}
		for package in packages where !Self.isSafeRelativePath(package) || !package.hasSuffix(".mlpackage") {
			throw DreamLiteError.invalidManifest("bad package name \(package)")
		}
		for file in files where !Self.isSafeRelativePath(file.path) || file.size < 0 || file.sha256.count != 64 {
			throw DreamLiteError.invalidManifest("bad file entry \(file.path)")
		}
	}

	/// Manifest paths are joined onto local directories and remote URLs, so they must stay inside them.
	static func isSafeRelativePath(_ path: String) -> Bool {
		guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\") else { return false }
		return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
			!$0.isEmpty && $0 != "." && $0 != ".."
		}
	}

	/// `DreamLiteUNet.mlpackage` -> `DreamLiteUNet`, the name Xcode gives the compiled `.mlmodelc`.
	static func modelName(_ package: String) -> String {
		(package as NSString).deletingPathExtension
	}
}

/// Compiled models ready for `MLModel.load(contentsOf:configuration:)`.
nonisolated struct DreamLiteCompiledModels: Equatable, Sendable {
	var manifest: DreamLiteManifest
	var textEncoderURLs: [URL]
	var unetURL: URL
	var decoderURL: URL

	/// Pairs each manifest package with `<name>.mlmodelc` under `directory`, or `nil` if any is missing.
	static func existing(manifest: DreamLiteManifest, in directory: URL) -> DreamLiteCompiledModels? {
		let urls = manifest.packages.map {
			directory.appendingPathComponent(DreamLiteManifest.modelName($0) + ".mlmodelc", isDirectory: true)
		}
		guard urls.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else { return nil }
		return DreamLiteCompiledModels(
			manifest: manifest,
			textEncoderURLs: Array(urls.dropLast(2)),
			unetURL: urls[urls.count - 2],
			decoderURL: urls[urls.count - 1]
		)
	}
}

nonisolated protocol DreamLiteFileDownloading: Sendable {
	func data(from url: URL) async throws -> Data
	/// Downloads `url` into a temporary file the caller then owns.
	func download(from url: URL) async throws -> URL
}

nonisolated struct URLSessionDreamLiteDownloader: DreamLiteFileDownloading {
	var session: URLSession = .shared

	func data(from url: URL) async throws -> Data {
		let (data, response) = try await session.data(from: url)
		try Self.check(response)
		return data
	}

	func download(from url: URL) async throws -> URL {
		let (location, response) = try await session.download(from: url)
		try Self.check(response)
		let owned = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.moveItem(at: location, to: owned)
		return owned
	}

	private static func check(_ response: URLResponse) throws {
		if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
			throw DreamLiteError.downloadFailed(http.statusCode)
		}
	}
}

/// Finds the DreamLite-mobile Core ML models: bundled with the app, installed in Application Support,
/// or downloaded once from `DREAMLITE_MODEL_BASE_URL` (a folder produced by `convert.py`).
actor DreamLiteModelStore {
	nonisolated struct Configuration: Sendable {
		static let baseURLInfoKey = "DREAMLITE_MODEL_BASE_URL"

		var bundle: Bundle = .main
		var installDirectory: URL
		var remoteBaseURL: URL?

		static var defaultInstallDirectory: URL {
			URL.applicationSupportDirectory
				.appendingPathComponent("DreamLite", isDirectory: true)
				.appendingPathComponent("Models", isDirectory: true)
		}

		static func fromInfoDictionary(_ info: [String: Any]?) -> Configuration {
			Configuration(
				installDirectory: defaultInstallDirectory,
				remoteBaseURL: configuredURL(info?[baseURLInfoKey])
			)
		}

		/// Unset build settings reach Info.plist as empty strings or as the literal `$(NAME)`.
		static func configuredURL(_ raw: Any?) -> URL? {
			guard let value = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
				!value.isEmpty,
				!value.hasPrefix("$("),
				let url = URL(string: value),
				url.scheme != nil
			else {
				return nil
			}
			return url
		}
	}

	typealias Compiler = @Sendable (URL) async throws -> URL

	private let configuration: Configuration
	private let downloader: any DreamLiteFileDownloading
	private let compile: Compiler
	private var resolved: DreamLiteCompiledModels?
	private var installation: Task<DreamLiteCompiledModels, Error>?

	init(
		configuration: Configuration = .fromInfoDictionary(Bundle.main.infoDictionary),
		downloader: any DreamLiteFileDownloading = URLSessionDreamLiteDownloader(),
		compile: @escaping Compiler = { try await MLModel.compileModel(at: $0) }
	) {
		self.configuration = configuration
		self.downloader = downloader
		self.compile = compile
	}

	func models() async throws -> DreamLiteCompiledModels {
		if let resolved { return resolved }
		if let bundled = try bundledModels() ?? installedModels() {
			resolved = bundled
			return bundled
		}
		if let installation {
			return try await installation.value
		}
		guard let baseURL = configuration.remoteBaseURL else {
			throw DreamLiteError.modelsUnavailable
		}
		let task = Task { try await install(from: baseURL) }
		installation = task
		defer { installation = nil }
		let installed = try await task.value
		resolved = installed
		return installed
	}

	private func bundledModels() throws -> DreamLiteCompiledModels? {
		let bundle = configuration.bundle
		guard
			let manifestURL = bundle.url(forResource: "DreamLiteManifest", withExtension: "json"),
			let resources = bundle.resourceURL
		else {
			return nil
		}
		let manifest = try DreamLiteManifest.decode(Data(contentsOf: manifestURL))
		return DreamLiteCompiledModels.existing(manifest: manifest, in: resources)
	}

	private func installedModels() -> DreamLiteCompiledModels? {
		let directory = configuration.installDirectory
		guard
			let data = try? Data(contentsOf: directory.appendingPathComponent(DreamLiteManifest.fileName)),
			let manifest = try? DreamLiteManifest.decode(data)
		else {
			return nil
		}
		return DreamLiteCompiledModels.existing(manifest: manifest, in: directory)
	}

	/// Downloads every manifest file, checks size and SHA-256, compiles the packages, then swaps the
	/// result into place. The manifest is written last, so an interrupted install is never picked up.
	private func install(from baseURL: URL) async throws -> DreamLiteCompiledModels {
		let fileManager = FileManager.default
		let manifestData = try await downloader.data(from: baseURL.appendingPathComponent(DreamLiteManifest.fileName))
		let manifest = try DreamLiteManifest.decode(manifestData)

		let root = configuration.installDirectory.deletingLastPathComponent()
		let staging = root.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
		let packages = staging.appendingPathComponent("packages", isDirectory: true)
		let compiled = staging.appendingPathComponent("compiled", isDirectory: true)
		try fileManager.createDirectory(at: packages, withIntermediateDirectories: true)
		try fileManager.createDirectory(at: compiled, withIntermediateDirectories: true)
		defer { try? fileManager.removeItem(at: staging) }

		for file in manifest.files {
			try Task.checkCancellation()
			let downloaded = try await downloader.download(from: Self.remoteURL(for: file.path, under: baseURL))
			do {
				try Self.verify(downloaded, matches: file)
				let destination = packages.appendingPathComponent(file.path)
				try fileManager.createDirectory(
					at: destination.deletingLastPathComponent(),
					withIntermediateDirectories: true
				)
				try fileManager.moveItem(at: downloaded, to: destination)
			} catch {
				try? fileManager.removeItem(at: downloaded)
				throw error
			}
		}

		for package in manifest.packages {
			try Task.checkCancellation()
			let source = packages.appendingPathComponent(package, isDirectory: true)
			let output = try await compile(source)
			let destination = compiled.appendingPathComponent(
				DreamLiteManifest.modelName(package) + ".mlmodelc",
				isDirectory: true
			)
			try fileManager.moveItem(at: output, to: destination)
			try? fileManager.removeItem(at: source)
		}
		try manifestData.write(to: compiled.appendingPathComponent(DreamLiteManifest.fileName))

		let install = configuration.installDirectory
		if fileManager.fileExists(atPath: install.path) {
			try fileManager.removeItem(at: install)
		}
		try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
		try fileManager.moveItem(at: compiled, to: install)
		var resourceValues = URLResourceValues()
		resourceValues.isExcludedFromBackup = true
		var excluded = install
		try? excluded.setResourceValues(resourceValues)

		guard let models = DreamLiteCompiledModels.existing(manifest: manifest, in: install) else {
			throw DreamLiteError.invalidManifest("compiled models missing after install")
		}
		return models
	}

	nonisolated static func remoteURL(for path: String, under baseURL: URL) -> URL {
		path.split(separator: "/").reduce(baseURL) { $0.appendingPathComponent(String($1)) }
	}

	nonisolated static func verify(_ url: URL, matches file: DreamLiteManifest.File) throws {
		let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
		let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
		guard size == file.size else {
			throw DreamLiteError.integrityCheckFailed(file.path)
		}
		let handle = try FileHandle(forReadingFrom: url)
		defer { try? handle.close() }
		var hasher = SHA256()
		while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
			hasher.update(data: chunk)
		}
		let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
		guard digest == file.sha256.lowercased() else {
			throw DreamLiteError.integrityCheckFailed(file.path)
		}
	}
}

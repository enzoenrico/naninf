//
//  DreamLiteIllustratorTests.swift
//  magoSanduicheTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import magoSanduiche

struct DreamLiteClientTests {
	private static let endpoint = URL(string: "https://dreamlite.test")!
	private static let completeStream = """
		event: heartbeat
		data: null

		event: complete
		data: [{"path": "/tmp/gradio/abc/image.png", "url": "https://dreamlite.test/gradio_api/file=/tmp/gradio/abc/image.png", "meta": {"_type": "gradio.FileData"}}]


		"""

	@Test func submitsTheMobileModelAndDownloadsTheResult() async throws {
		let imageData = try pngData(width: 4, height: 2)
		let transport = StubDreamLiteTransport(responses: [
			Data(#"{"event_id":"evt1"}"#.utf8),
			Data(Self.completeStream.utf8),
			imageData,
		])
		var configuration = DreamLiteConfiguration(endpoint: Self.endpoint, accessToken: "hf_token")
		configuration.seed = 7
		let client = DreamLiteClient(configuration: configuration, transport: transport)

		let data = try await client.generateImageData(prompt: "  Torchlit corridor  ")

		#expect(data == imageData)
		let requests = await transport.requests
		#expect(requests.count == 3)
		#expect(requests[0].httpMethod == "POST")
		#expect(requests[0].url?.absoluteString == "https://dreamlite.test/gradio_api/call/generate_image")
		#expect(requests[1].url?.absoluteString == "https://dreamlite.test/gradio_api/call/generate_image/evt1")
		#expect(requests[2].url?.absoluteString == "https://dreamlite.test/gradio_api/file=/tmp/gradio/abc/image.png")
		#expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer hf_token" })

		let body = try #require(requests[0].httpBody)
		let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
		let payload = try #require(object["data"] as? [Any])
		#expect(payload[0] as? String == DreamLiteConfiguration.modelChoice)
		#expect(payload[1] as? String == "Torchlit corridor")
		#expect(payload[2] is NSNull)
		#expect(payload[4] as? Int == 4)
		#expect(payload[7] as? Int == 7)
	}

	@Test func errorEventsFailTheGeneration() async {
		let transport = StubDreamLiteTransport(responses: [
			Data(#"{"event_id":"evt1"}"#.utf8),
			Data("event: error\ndata: \"GPU quota exceeded\"\n\n".utf8),
		])
		let client = DreamLiteClient(
			configuration: DreamLiteConfiguration(endpoint: Self.endpoint),
			transport: transport
		)

		await #expect(throws: DreamLiteError.generationFailed("GPU quota exceeded")) {
			try await client.generateImageData(prompt: "A dark stair")
		}
	}

	@Test func httpFailuresSurfaceTheStatus() async {
		let transport = StubDreamLiteTransport(responses: [Data()], statusCode: 503)
		let client = DreamLiteClient(
			configuration: DreamLiteConfiguration(endpoint: Self.endpoint),
			transport: transport
		)

		await #expect(throws: DreamLiteError.httpStatus(503)) {
			try await client.generateImageData(prompt: "A dark stair")
		}
	}

	@Test func emptyPromptsNeverReachTheNetwork() async {
		let transport = StubDreamLiteTransport(responses: [])
		let client = DreamLiteClient(transport: transport)

		await #expect(throws: DreamLiteError.emptyPrompt) {
			try await client.generateImageData(prompt: "   ")
		}
		#expect(await transport.requests.isEmpty)
	}

	@Test func pathOnlyPayloadsResolveAgainstTheEndpoint() throws {
		let stream = "event: complete\r\ndata: [{\"path\": \"/tmp/x.webp\", \"url\": null}]\r\n\r\n"

		let url = try DreamLiteEventStream.imageURL(in: stream, endpoint: Self.endpoint)

		#expect(url.absoluteString == "https://dreamlite.test/gradio_api/file=/tmp/x.webp")
	}

	@Test func unsetBuildSettingsFallBackToTheHostedSpace() {
		let configuration = DreamLiteConfiguration.fromInfoDictionary([
			DreamLiteConfiguration.endpointInfoKey: "$(DREAMLITE_ENDPOINT)",
			DreamLiteConfiguration.accessTokenInfoKey: "",
		])

		#expect(configuration.endpoint == DreamLiteConfiguration.defaultEndpoint)
		#expect(configuration.accessToken == nil)
	}

	@Test func configuredEndpointAndTokenApply() {
		let configuration = DreamLiteConfiguration.fromInfoDictionary([
			DreamLiteConfiguration.endpointInfoKey: "http://192.168.0.5:7860",
			DreamLiteConfiguration.accessTokenInfoKey: "hf_x",
		])

		#expect(configuration.endpoint.absoluteString == "http://192.168.0.5:7860")
		#expect(configuration.accessToken == "hf_x")
	}
}

struct DreamLiteIllustratorTests {
	@Test @MainActor func generatedBytesBecomeTheRenderedScene() async throws {
		let transport = StubDreamLiteTransport(responses: [
			Data(#"{"event_id":"evt1"}"#.utf8),
			Data("event: complete\ndata: [{\"url\": \"https://dreamlite.test/image.png\"}]\n\n".utf8),
			try pngData(width: 4, height: 2),
		])
		let illustrator = DreamLiteIllustrator(
			client: DreamLiteClient(
				configuration: DreamLiteConfiguration(endpoint: URL(string: "https://dreamlite.test")!),
				transport: transport
			)
		)
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: illustrator
			)
		)
		vm.hasSubmittedPlayerTurn = true

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", turnID: "turn")

		guard case .scene(let scene) = vm.visionDisplayMode else {
			Issue.record("expected a DreamLite scene")
			return
		}
		#expect(scene.cgImage.width == 4)
		#expect(scene.cgImage.height == 2)
		#expect(!vm.visionMediaLoading)
	}

	@Test @MainActor func undecodableBytesKeepTheCurrentFrame() async {
		let transport = StubDreamLiteTransport(responses: [
			Data(#"{"event_id":"evt1"}"#.utf8),
			Data("event: complete\ndata: [{\"url\": \"https://dreamlite.test/image.png\"}]\n\n".utf8),
			Data("not an image".utf8),
		])
		let vm = GameViewModel(
			persistRunsToLibrary: false,
			dungeonMaster: DungeonMasterService(
				narrator: ScriptedNarrator(drafts: []),
				illustrator: DreamLiteIllustrator(client: DreamLiteClient(transport: transport))
			)
		)
		vm.hasSubmittedPlayerTurn = true

		await vm.handleVisionAfterTurn(visualPrompt: "Torchlit corridor", turnID: "turn")

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

		let slowTurn = Task { await vm.handleVisionAfterTurn(visualPrompt: "slow", turnID: "turn-1") }
		try await Task.sleep(for: .milliseconds(20))
		await vm.handleVisionAfterTurn(visualPrompt: "fast", turnID: "turn-2")
		await slowTurn.value

		guard case .scene(let scene) = vm.visionDisplayMode else {
			Issue.record("expected the newer scene")
			return
		}
		#expect(scene.cgImage.width == 1)
		#expect(!vm.visionMediaLoading)
	}
}

private actor StubDreamLiteTransport: DreamLiteTransport {
	private var responses: [Data]
	private let statusCode: Int
	private(set) var requests: [URLRequest] = []

	init(responses: [Data], statusCode: Int = 200) {
		self.responses = responses
		self.statusCode = statusCode
	}

	func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		requests.append(request)
		let url = try #require(request.url)
		let response = try #require(
			HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
		)
		guard !responses.isEmpty else { throw URLError(.badServerResponse) }
		return (responses.removeFirst(), response)
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

private func pngData(width: Int, height: Int) throws -> Data {
	let image = try solidImage(width: width, height: height)
	let data = NSMutableData()
	guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
		throw SceneMediaError.noImage
	}
	CGImageDestinationAddImage(destination, image, nil)
	guard CGImageDestinationFinalize(destination) else { throw SceneMediaError.noImage }
	return data as Data
}

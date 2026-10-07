//
//  DreamLiteClient.swift
//  magoSanduiche
//

import Foundation

#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

/// Text-to-image settings for `carlofkl/DreamLite-mobile`, served through the DreamLite Gradio app.
nonisolated struct DreamLiteConfiguration: Sendable, Equatable {
	static let modelID = "carlofkl/DreamLite-mobile"
	static let modelChoice = "DreamLite-mobile"
	static let defaultEndpoint = URL(string: "https://carlofkl-dreamlite.hf.space")!
	static let endpointInfoKey = "DREAMLITE_ENDPOINT"
	static let accessTokenInfoKey = "DREAMLITE_HF_TOKEN"

	var endpoint: URL
	/// Hugging Face token. ZeroGPU Spaces grant more GPU quota to authenticated callers.
	var accessToken: String?
	/// The mobile distillation is trained for 1024×1024.
	var resolution = "1024 × 1024 (1:1)"
	/// The mobile distillation has no CFG and is tuned for 4–8 steps.
	var inferenceSteps = 4
	var guidanceScale = 1.0
	var imageGuidanceScale = 1.0
	/// `nil` draws a fresh seed for every scene.
	var seed: Int?
	var requestTimeout: TimeInterval = 180

	init(endpoint: URL = Self.defaultEndpoint, accessToken: String? = nil) {
		self.endpoint = endpoint
		self.accessToken = accessToken
	}

	static func fromInfoDictionary(_ info: [String: Any]?) -> Self {
		let endpoint = configuredValue(info?[endpointInfoKey]).flatMap(URL.init(string:)) ?? defaultEndpoint
		return Self(endpoint: endpoint, accessToken: configuredValue(info?[accessTokenInfoKey]))
	}

	/// Unset build settings reach Info.plist as empty strings or as the literal `$(NAME)`.
	private static func configuredValue(_ raw: Any?) -> String? {
		guard let value = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
			!value.isEmpty,
			!value.hasPrefix("$(")
		else {
			return nil
		}
		return value
	}
}

nonisolated enum DreamLiteError: Error, LocalizedError, Equatable {
	case emptyPrompt
	case invalidResponse
	case httpStatus(Int)
	case generationFailed(String?)
	case missingImage

	var errorDescription: String? {
		switch self {
		case .emptyPrompt:
			"DreamLite needs a non-empty prompt"
		case .invalidResponse:
			"DreamLite returned an unreadable response"
		case .httpStatus(let status):
			"DreamLite returned HTTP \(status)"
		case .generationFailed(let message):
			message.map { "DreamLite failed: \($0)" } ?? "DreamLite failed to generate an image"
		case .missingImage:
			"DreamLite finished without an image"
		}
	}

	var analyticsKind: String {
		switch self {
		case .emptyPrompt: "dreamlite_empty_prompt"
		case .invalidResponse: "dreamlite_invalid_response"
		case .httpStatus: "dreamlite_http_status"
		case .generationFailed: "dreamlite_generation_failed"
		case .missingImage: "dreamlite_missing_image"
		}
	}
}

nonisolated protocol DreamLiteTransport: Sendable {
	func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

nonisolated struct URLSessionDreamLiteTransport: DreamLiteTransport {
	var session: URLSession = .shared

	func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		try await session.data(for: request)
	}
}

/// Gradio queue protocol: `POST /gradio_api/call/<fn>` returns an event id, and
/// `GET /gradio_api/call/<fn>/<id>` streams server-sent events until `complete` or `error`.
nonisolated struct DreamLiteClient: Sendable {
	static let apiName = "generate_image"

	let configuration: DreamLiteConfiguration
	let transport: any DreamLiteTransport

	init(
		configuration: DreamLiteConfiguration = DreamLiteConfiguration(),
		transport: any DreamLiteTransport = URLSessionDreamLiteTransport()
	) {
		self.configuration = configuration
		self.transport = transport
	}

	/// Returns encoded image bytes (WebP from the hosted Space).
	func generateImageData(prompt: String) async throws -> Data {
		let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { throw DreamLiteError.emptyPrompt }

		let eventID = try await submit(prompt: trimmed)
		try Task.checkCancellation()
		let imageURL = try await awaitResult(eventID: eventID)
		try Task.checkCancellation()
		return try await download(imageURL)
	}

	func submitRequest(prompt: String) throws -> URLRequest {
		var request = makeRequest(url: callURL)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let seed = configuration.seed ?? Int.random(in: 0...999_999)
		let payload: [String: Any] = [
			"data": [
				DreamLiteConfiguration.modelChoice,
				prompt,
				NSNull(),
				configuration.resolution,
				configuration.inferenceSteps,
				configuration.guidanceScale,
				configuration.imageGuidanceScale,
				seed,
			],
		]
		request.httpBody = try JSONSerialization.data(withJSONObject: payload)
		return request
	}

	private var callURL: URL {
		configuration.endpoint
			.appendingPathComponent("gradio_api")
			.appendingPathComponent("call")
			.appendingPathComponent(Self.apiName)
	}

	private func submit(prompt: String) async throws -> String {
		let data = try await send(submitRequest(prompt: prompt))
		guard
			let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			let eventID = object["event_id"] as? String,
			!eventID.isEmpty
		else {
			throw DreamLiteError.invalidResponse
		}
		return eventID
	}

	private func awaitResult(eventID: String) async throws -> URL {
		var request = makeRequest(url: callURL.appendingPathComponent(eventID))
		request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
		let data = try await send(request)
		guard let stream = String(data: data, encoding: .utf8) else {
			throw DreamLiteError.invalidResponse
		}
		return try DreamLiteEventStream.imageURL(in: stream, endpoint: configuration.endpoint)
	}

	private func download(_ url: URL) async throws -> Data {
		let data = try await send(makeRequest(url: url))
		guard !data.isEmpty else { throw DreamLiteError.missingImage }
		return data
	}

	private func makeRequest(url: URL) -> URLRequest {
		var request = URLRequest(url: url, timeoutInterval: configuration.requestTimeout)
		if let token = configuration.accessToken {
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}
		return request
	}

	private func send(_ request: URLRequest) async throws -> Data {
		let (data, response) = try await transport.data(for: request)
		guard let http = response as? HTTPURLResponse else {
			throw DreamLiteError.invalidResponse
		}
		guard (200..<300).contains(http.statusCode) else {
			throw DreamLiteError.httpStatus(http.statusCode)
		}
		return data
	}
}

nonisolated enum DreamLiteEventStream {
	struct Event: Equatable {
		var name: String
		var data: String
	}

	static func events(in stream: String) -> [Event] {
		var events: [Event] = []
		var name = "message"
		var dataLines: [String] = []

		func flush() {
			if !dataLines.isEmpty {
				events.append(Event(name: name, data: dataLines.joined(separator: "\n")))
			}
			name = "message"
			dataLines = []
		}

		for line in stream.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
			if line.isEmpty {
				flush()
			} else if line.hasPrefix("event:") {
				name = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
			} else if line.hasPrefix("data:") {
				dataLines.append(line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces))
			}
		}
		flush()
		return events
	}

	static func imageURL(in stream: String, endpoint: URL) throws -> URL {
		for event in events(in: stream) {
			switch event.name {
			case "complete":
				return try imageURL(fromCompletePayload: event.data, endpoint: endpoint)
			case "error":
				throw DreamLiteError.generationFailed(errorMessage(from: event.data))
			default:
				continue
			}
		}
		throw DreamLiteError.missingImage
	}

	private static func imageURL(fromCompletePayload payload: String, endpoint: URL) throws -> URL {
		guard
			let data = payload.data(using: .utf8),
			let outputs = try? JSONSerialization.jsonObject(with: data) as? [Any]
		else {
			throw DreamLiteError.invalidResponse
		}
		guard let file = outputs.first as? [String: Any] else {
			throw DreamLiteError.missingImage
		}
		if let urlString = file["url"] as? String, let url = URL(string: urlString) {
			return url
		}
		if let path = file["path"] as? String, !path.isEmpty,
			let url = URL(string: "gradio_api/file=\(path)", relativeTo: directoryURL(endpoint))?.absoluteURL
		{
			return url
		}
		throw DreamLiteError.missingImage
	}

	private static func directoryURL(_ endpoint: URL) -> URL {
		endpoint.absoluteString.hasSuffix("/") ? endpoint : endpoint.appendingPathComponent("")
	}

	private static func errorMessage(from payload: String) -> String? {
		let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty, trimmed != "null" else { return nil }
		if let data = trimmed.data(using: .utf8),
			let decoded = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
		{
			if let message = decoded as? String { return message }
			if let object = decoded as? [String: Any], let message = object["message"] as? String {
				return message
			}
		}
		return trimmed
	}
}

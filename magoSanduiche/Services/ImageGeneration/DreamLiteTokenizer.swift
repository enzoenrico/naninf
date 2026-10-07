//
//  DreamLiteTokenizer.swift
//  magoSanduiche
//

import Foundation

/// Byte-level BPE matching `Qwen2TokenizerFast` (NFC, Qwen2 split regex, GPT-2 byte map, ranked merges).
nonisolated final class DreamLiteTokenizer: @unchecked Sendable {
	private static let whitespace = "\\t\\n\\x{0B}\\f\\r\\x{85}\\p{Z}"
	/// The Hugging Face pattern with `\s`/`\S` spelled out: ICU's `\s` omits U+000B and U+0085.
	private static let splitPattern =
		"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\\r\\n\\p{L}\\p{N}]?\\p{L}+|\\p{N}| ?[^\(whitespace)\\p{L}\\p{N}]+[\\r\\n]*|[\(whitespace)]*[\\r\\n]+|[\(whitespace)]+(?![^\(whitespace)])|[\(whitespace)]+"

	private let vocabulary: [String: Int]
	private let mergeRanks: [String: Int]
	private let addedTokens: [(content: String, id: Int)]
	private let splitExpression: NSRegularExpression
	private let byteEncoder: [Character]
	private let lock = NSLock()
	private var cache: [String: [Int]] = [:]

	init(vocabulary: [String: Int], merges: [(String, String)], addedTokens: [String: Int]) throws {
		self.vocabulary = vocabulary
		var ranks: [String: Int] = [:]
		ranks.reserveCapacity(merges.count)
		for (rank, merge) in merges.enumerated() where ranks["\(merge.0) \(merge.1)"] == nil {
			ranks["\(merge.0) \(merge.1)"] = rank
		}
		self.mergeRanks = ranks
		self.addedTokens = addedTokens
			.map { (content: $0.key, id: $0.value) }
			.sorted { $0.content.count > $1.content.count }
		self.splitExpression = try NSRegularExpression(pattern: Self.splitPattern)
		self.byteEncoder = Self.makeByteEncoder()
	}

	convenience init(vocabularyURL: URL, mergesURL: URL, addedTokensURL: URL) throws {
		let vocabulary = try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: vocabularyURL))
		let addedTokens = try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: addedTokensURL))
		let mergesText = try String(contentsOf: mergesURL, encoding: .utf8)
		var merges: [(String, String)] = []
		merges.reserveCapacity(152_000)
		for line in mergesText.split(whereSeparator: \.isNewline) where !line.hasPrefix("#version") {
			let parts = line.split(separator: " ", omittingEmptySubsequences: true)
			guard parts.count == 2 else { continue }
			merges.append((String(parts[0]), String(parts[1])))
		}
		try self.init(vocabulary: vocabulary, merges: merges, addedTokens: addedTokens)
	}

	/// The DreamLite-mobile tokenizer files shipped in `Resources/DreamLite`.
	static func bundled(in bundle: Bundle) throws -> DreamLiteTokenizer {
		guard
			let vocabulary = bundle.url(forResource: "dreamlite_vocab", withExtension: "json"),
			let merges = bundle.url(forResource: "dreamlite_merges", withExtension: "txt"),
			let addedTokens = bundle.url(forResource: "dreamlite_added_tokens", withExtension: "json")
		else {
			throw DreamLiteError.tokenizerUnavailable
		}
		return try DreamLiteTokenizer(vocabularyURL: vocabulary, mergesURL: merges, addedTokensURL: addedTokens)
	}

	func id(forAddedToken content: String) -> Int? {
		addedTokens.first { $0.content == content }?.id
	}

	func encode(_ text: String) -> [Int] {
		let normalized = text.precomposedStringWithCanonicalMapping
		var ids: [Int] = []
		for segment in splitAddedTokens(normalized) {
			switch segment {
			case .added(let id):
				ids.append(id)
			case .text(let text):
				for piece in preTokenize(text) {
					ids.append(contentsOf: encodePiece(piece))
				}
			}
		}
		return ids
	}

	private enum Segment {
		case added(Int)
		case text(String)
	}

	private func splitAddedTokens(_ text: String) -> [Segment] {
		var segments: [Segment] = []
		var pending = ""
		var index = text.startIndex
		outer: while index < text.endIndex {
			for token in addedTokens where text[index...].hasPrefix(token.content) {
				if !pending.isEmpty {
					segments.append(.text(pending))
					pending = ""
				}
				segments.append(.added(token.id))
				index = text.index(index, offsetBy: token.content.count)
				continue outer
			}
			pending.append(text[index])
			index = text.index(after: index)
		}
		if !pending.isEmpty {
			segments.append(.text(pending))
		}
		return segments
	}

	/// `Split(behavior: Isolated)`: every match and every unmatched gap becomes its own piece.
	private func preTokenize(_ text: String) -> [String] {
		let nsText = text as NSString
		var pieces: [String] = []
		var cursor = 0
		for match in splitExpression.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
			if match.range.location > cursor {
				pieces.append(nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
			}
			if match.range.length > 0 {
				pieces.append(nsText.substring(with: match.range))
			}
			cursor = match.range.location + match.range.length
		}
		if cursor < nsText.length {
			pieces.append(nsText.substring(from: cursor))
		}
		return pieces
	}

	private func encodePiece(_ piece: String) -> [Int] {
		lock.lock()
		if let cached = cache[piece] {
			lock.unlock()
			return cached
		}
		lock.unlock()

		let mapped = piece.utf8.map { String(byteEncoder[Int($0)]) }
		let ids = bytePairMerge(mapped).compactMap { vocabulary[$0] }

		lock.lock()
		if cache.count > 4096 { cache.removeAll(keepingCapacity: true) }
		cache[piece] = ids
		lock.unlock()
		return ids
	}

	private func bytePairMerge(_ symbols: [String]) -> [String] {
		var word = symbols
		guard word.count > 1 else { return word }
		while true {
			var best: (rank: Int, first: String, second: String)?
			for i in 0..<(word.count - 1) {
				if let rank = mergeRanks["\(word[i]) \(word[i + 1])"], rank < (best?.rank ?? .max) {
					best = (rank, word[i], word[i + 1])
				}
			}
			guard let best else { return word }
			var merged: [String] = []
			merged.reserveCapacity(word.count)
			var i = 0
			while i < word.count {
				if i < word.count - 1, word[i] == best.first, word[i + 1] == best.second {
					merged.append(best.first + best.second)
					i += 2
				} else {
					merged.append(word[i])
					i += 1
				}
			}
			word = merged
			if word.count == 1 { return word }
		}
	}

	/// GPT-2 `bytes_to_unicode`: printable bytes map to themselves, the rest to U+0100 onward.
	private static func makeByteEncoder() -> [Character] {
		let printable = Array(33...126) + Array(161...172) + Array(174...255)
		var table = [Character](repeating: " ", count: 256)
		var next = 0
		for byte in 0..<256 {
			if printable.contains(byte) {
				table[byte] = Character(UnicodeScalar(UInt8(byte)))
			} else {
				table[byte] = Character(UnicodeScalar(256 + next)!)
				next += 1
			}
		}
		return table
	}
}

/// Builds the fixed text-encoder window exactly like `DreamLiteMobilePipeline.encode_prompt(mode: "generate")`.
nonisolated struct DreamLitePromptEncoder: Sendable {
	static let systemTemplate =
		"<|im_start|>system\nDescribe the image by detailing the color, shape, size, texture, "
		+ "quantity, text, spatial relationships of the objects and background:<|im_end|>\n"
		+ "<|im_start|>user\n%@<|im_end|>\n<|im_start|>assistant\n"
	static let promptPrefix = "[Generate]: "
	static let assistantSuffix = "<|im_end|>\n<|im_start|>assistant\n"

	struct Window: Equatable, Sendable {
		/// Right-padded token ids, `sequenceLength` long.
		var tokenIDs: [Int32]
		/// Text-encoder outputs that carry the prompt (after the system prefix is dropped).
		var validEmbeddingCount: Int
	}

	let tokenizer: DreamLiteTokenizer
	var sequenceLength = 256
	var dropTokenCount = 34
	var padTokenID = 151_643

	func window(for prompt: String) -> Window {
		let text = Self.systemTemplate.replacingOccurrences(of: "%@", with: Self.promptPrefix + prompt)
		var ids = tokenizer.encode(text)
		if ids.count > sequenceLength {
			let suffix = tokenizer.encode(Self.assistantSuffix)
			ids = Array(ids.prefix(sequenceLength - suffix.count)) + suffix
		}
		let valid = ids.count - dropTokenCount
		ids.append(contentsOf: repeatElement(padTokenID, count: sequenceLength - ids.count))
		return Window(tokenIDs: ids.map(Int32.init), validEmbeddingCount: valid)
	}
}

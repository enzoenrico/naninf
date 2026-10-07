//
//  TypeWriterView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import SwiftUI
import Foundation

struct TypeWriterView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	var embedsScrollView: Bool
	var lineLimit: Int?
	var content: [Character]
	var initialRevealedCount: Int
	var onProgress: ((Int) -> Void)?
	var onFinished: (() -> Void)?

	@State private var revealedCount: Int
	@State private var scrambleGlyph: Character?
	@State private var hasFinishedTyping = false
	@State private var cursorVisible = true

	init(
		_ content: String,
		embedsScrollView: Bool = false,
		lineLimit: Int? = nil,
		initialRevealedCount: Int = 0,
		onProgress: ((Int) -> Void)? = nil,
		onFinished: (() -> Void)? = nil
	) {
		self.embedsScrollView = embedsScrollView
		self.lineLimit = lineLimit
		self.content = content.map { $0 }
		self.initialRevealedCount = min(max(0, initialRevealedCount), self.content.count)
		self.onProgress = onProgress
		self.onFinished = onFinished
		_revealedCount = State(initialValue: self.initialRevealedCount)
	}

	var body: some View {
		Group {
			if embedsScrollView {
				ScrollView {
					VStack {
						typewriterText
					}
				}
				.defaultScrollAnchor(.bottom)
			} else {
				typewriterText
			}
		}
		.frame(maxWidth: .infinity)
		.clipped()
		.contentShape(Rectangle())
		.onTapGesture {
			finishImmediately()
		}
		.accessibilityLabel(fullText)
		.accessibilityHint(
			hasFinishedTyping
				? String(localized: "nan_typewriter_a11y_complete")
				: String(localized: "nan_typewriter_a11y_tap_reveal")
		)
		.enableInjection()
	}

	private var typewriterText: some View {
		Text(renderedText)
			.font(.monocraft())
			.foregroundStyle(Color.accent)
			.lineLimit(lineLimit)
			.frame(maxWidth: .infinity, alignment: .leading)
			.task(id: fullText) { await buildContent() }
			.task { await blinkCursor() }
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private var fullText: String {
		String(content)
	}

	/// The word being typed is laid out in full (transparent) so it wraps once, up front,
	/// instead of jumping to the next line mid-word. The cursor is a background on the
	/// first hidden character, so blinking never changes glyphs or line metrics.
	private var renderedText: AttributedString {
		guard !hasFinishedTyping else { return AttributedString(fullText) }

		let revealedEnd = min(revealedCount, content.count)
		var revealed = Array(content[..<revealedEnd])
		if let scrambleGlyph, !revealed.isEmpty {
			revealed[revealed.count - 1] = scrambleGlyph
		}

		var text = AttributedString(String(revealed))
		var pending = AttributedString(String(content[revealedEnd ..< upcomingWordEnd(from: revealedEnd)]))
		pending.foregroundColor = Color.clear
		if cursorVisible, let first = pending.characters.indices.first {
			pending[first ..< pending.characters.index(after: first)].backgroundColor = Color.accent
		}
		text.append(pending)
		return text
	}

	private func upcomingWordEnd(from start: Int) -> Int {
		var end = start
		if end < content.count, content[end].isWhitespace {
			end += 1
		}
		while end < content.count, !content[end].isWhitespace {
			end += 1
		}
		return end
	}

	private func scrambleLastCharacter(times: Int) async {
		for _ in 0 ..< times {
			guard !hasFinishedTyping else { return }
			scrambleGlyph = TerminalMotion.typewriterScrambleGlyphs.randomElement()
			try? await Task.sleep(for: TerminalMotion.typewriterStepDelay)
		}
		scrambleGlyph = nil
	}

	private func buildContent() async {
		let resumeFrom = min(max(0, initialRevealedCount), content.count)

		if resumeFrom >= content.count {
			finishImmediately()
			return
		}

		hasFinishedTyping = false
		scrambleGlyph = nil
		revealedCount = resumeFrom

		guard !reduceMotion else {
			finishImmediately()
			return
		}

		guard !content.isEmpty else {
			hasFinishedTyping = true
			onProgress?(0)
			onFinished?()
			return
		}

		for index in resumeFrom ..< content.count {
			guard !hasFinishedTyping else { return }
			let character = content[index]
			revealedCount = index + 1
			if character.isLetter || character.isNumber {
				await scrambleLastCharacter(times: 3)
			}
			try? await Task.sleep(for: TerminalMotion.typewriterStepDelay)
			// Reported per word, not per character, so observers don't re-render on every keystroke.
			if character.isWhitespace {
				onProgress?(revealedCount)
			}
		}

		hasFinishedTyping = true
		onProgress?(content.count)
		onFinished?()
	}

	private func finishImmediately() {
		guard !hasFinishedTyping else { return }
		revealedCount = content.count
		scrambleGlyph = nil
		hasFinishedTyping = true
		cursorVisible = false
		onProgress?(content.count)
		onFinished?()
	}

	private func blinkCursor() async {
		guard !reduceMotion else {
			cursorVisible = false
			return
		}

		while !Task.isCancelled {
			try? await Task.sleep(for: TerminalMotion.cursorInterval)
			guard !hasFinishedTyping else {
				cursorVisible = false
				continue
			}
			cursorVisible.toggle()
		}
	}
}

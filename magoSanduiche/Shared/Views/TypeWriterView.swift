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

	@State private var temp: [Character]
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
		_temp = State(initialValue: Array(repeating: " ", count: self.content.count))
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

	private var renderedText: String {
		let cursor = cursorVisible ? TerminalMotion.cursorSymbol : " "
		return hasFinishedTyping ? String(temp) : String(temp) + cursor
	}

	private func swapLetter(at index: Int, target: Int) async {
		guard !hasFinishedTyping else { return }
		guard target >= 0 else {
			returnToOriginal(at: index)
			return
		}

		temp[index] = TerminalMotion.scrambleGlyphs.randomElement() ?? content[index]
		try? await Task.sleep(for: TerminalMotion.typewriterStepDelay)
		await swapLetter(at: index, target: target - 1)
	}

	private func returnToOriginal(at index: Int) {
		temp[index] = content[index]
	}

	private func buildContent() async {
		let resumeFrom = min(max(0, initialRevealedCount), content.count)

		if resumeFrom >= content.count {
			finishImmediately()
			return
		}

		hasFinishedTyping = false
		if resumeFrom == 0 {
			temp = Array(repeating: " ", count: content.count)
		} else {
			temp = Array(repeating: " ", count: content.count)
			for index in 0 ..< resumeFrom {
				temp[index] = content[index]
			}
		}

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
			temp[index] = content[index]
			await swapLetter(at: index, target: 2)
			try? await Task.sleep(for: TerminalMotion.typewriterStepDelay)
			onProgress?(index + 1)
		}

		hasFinishedTyping = true
		onProgress?(content.count)
		onFinished?()
	}

	private func finishImmediately() {
		guard !hasFinishedTyping else { return }
		temp = content
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

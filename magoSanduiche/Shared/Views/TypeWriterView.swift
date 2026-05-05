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
	var content: [Character]
	var onFinished: (() -> Void)?

	@State private var temp: [Character]
	@State private var hasFinishedTyping = false
	@State private var cursorVisible = true

	init(_ content: String, onFinished: (() -> Void)? = nil) {
		self.content = content.map { $0 }
		self.onFinished = onFinished
		_temp = State(initialValue: Array(repeating: " ", count: self.content.count))
	}

	var body: some View {
		ScrollView {
			VStack {
				Text(renderedText)
					.font(.monocraft())
					.foregroundStyle(Color.accent)
					.frame(maxWidth: .infinity, alignment: .leading)
					.task(id: fullText) { await buildContent() }
					.task { await blinkCursor() }
			}
		}
		.defaultScrollAnchor(.bottom)
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
		hasFinishedTyping = false
		temp = Array(repeating: " ", count: content.count)

		guard !reduceMotion else {
			finishImmediately()
			return
		}

		guard !content.isEmpty else {
			hasFinishedTyping = true
			onFinished?()
			return
		}

		for index in content.indices {
			guard !hasFinishedTyping else { return }
			temp[index] = content[index]
			await swapLetter(at: index, target: 2)
			try? await Task.sleep(for: TerminalMotion.typewriterStepDelay)
		}

		hasFinishedTyping = true
		onFinished?()
	}

	private func finishImmediately() {
		guard !hasFinishedTyping else { return }
		temp = content
		hasFinishedTyping = true
		cursorVisible = false
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

//
//  TypeWriterView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import Foundation
import SwiftUI

struct TypeWriterView: View {
	var content: [Character]
	var onFinished: (() -> Void)?
	@State private var temp: [Character]
	@State private var hasFinishedTyping = false

	init(_ content: String, onFinished: (() -> Void)? = nil) {
		self.content = content.map { $0 }
		self.onFinished = onFinished
		_temp = State(initialValue: Array(repeating: " ", count: self.content.count))
	}

	var body: some View {
    ScrollView {
			VStack {
				Text(String(temp))
					.font(.monocraft())
					.foregroundStyle(Color.accent)
					.task { await buildContent() }  // fires at appear
					.onChange(of: content) { oldState, newState in
							hasFinishedTyping = false
							temp = Array(repeating: " ", count: newState.count)
							Task {
								await buildContent()
							}
					}
			}
		}
		.defaultScrollAnchor(.bottom)
		.frame(maxWidth: .infinity)
		.clipped()
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private func swapLetter(at index: Int, target: Int) async {
		guard target >= 0 else {
			returnToOriginal(at: index)
			return
		}
		let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ$#@|&*~`.<>/?"
		temp[index] = letters.randomElement()!
		try? await Task.sleep(for: .milliseconds(5))
		await swapLetter(at: index, target: target - 1)
	}

	private func returnToOriginal(at index: Int) {
		temp[index] = content[index]
	}

	private func buildContent() async {
		guard !hasFinishedTyping else { return }

		guard !content.isEmpty else {
			hasFinishedTyping = true
			onFinished?()
			return
		}

		for idx in content.indices {
			temp[idx] = content[idx]

			let target = 2
			await swapLetter(
				at: idx,
				target: target
			)

			try? await Task.sleep(for: .milliseconds(5))
		}

		hasFinishedTyping = true
		onFinished?()
	}
}

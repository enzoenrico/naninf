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
	@State private var temp: [Character]

	init(_ content: String) {
		self.content = content.map { $0 }
		_temp = State(initialValue: Array(repeating: " ", count: self.content.count))
	}

	var body: some View {
		ScrollView {
			VStack {
				Text(String(temp))
					.font(.body)
					.fontDesign(.monospaced)
					.foregroundStyle(Color.accent)
					.task { await buildContent() }  // fires at appear
			}
		}
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
		let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		temp[index] = letters.randomElement()!
		try? await Task.sleep(for: .milliseconds(15))
		await swapLetter(at: index, target: target - 1)
	}

	private func returnToOriginal(at index: Int) {
		temp[index] = content[index]
	}

	private func buildContent() async {
		for idx in content.indices {
			temp[idx] = content[idx]

			Task { @MainActor in
				let target = 2
				await swapLetter(
					at: idx,
					target: target,
				)
			}

			try? await Task.sleep(for: .milliseconds(15))
		}
	}
}

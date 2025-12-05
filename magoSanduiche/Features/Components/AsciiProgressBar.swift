//
//  AsciiProgressBar.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import Foundation
import SwiftUI

enum BarTypes: String {
	case health
	case mana

	var label: String {
		switch self {
		case .health: "HP"
		case .mana: "MP"
		}
	}
}

struct AsciiProgressBar: View {
	var barType: BarTypes
	var progress: Int
	var maxProgress: Int = 18

	init(_ barType: BarTypes, progress: Int = 2) {
		self.barType = barType
		self.progress = progress
	}

	var body: some View {
		HStack(alignment: .center, spacing: 5) {
			Text(barType.label)
				.foregroundStyle(.accent)
			Bar(
				progress: progress,
				maxProgress: maxProgress
			)
		}
		.frame(maxWidth: .infinity, maxHeight: 25)
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	// MARK: - the bar
	private struct Bar: View {
		let progress: Int
		let maxProgress: Int

		private let chars = ["█", "▓", "▒", "░"]
		private let fontSize: CGFloat = 16
		private var charWidth: CGFloat { fontSize * 0.65 }

		var body: some View {
			GeometryReader { geo in
				let charCount = calculateCharCount(for: geo.size.width)
				Text(populateBar(charCount: charCount))
					.font(.system(size: fontSize, design: .monospaced))
					.frame(height: geo.size.height, alignment: .center)

			}
			.enableInjection()
		}

		private func calculateCharCount(for width: CGFloat) -> Int {
			max(1, Int(width / charWidth))
		}

		private func populateBar(charCount: Int) -> AttributedString {
			let progressRatio = Double(progress) / Double(maxProgress)
			let filledCount = Int(Double(charCount) * progressRatio)
			var attributedString = AttributedString()

			for i in 0..<charCount {
				var char = chooseChar(i, totalChars: charCount)
				char.foregroundColor = i < filledCount ? Color.accent : Color.gray
				attributedString += char
			}

			return attributedString
		}

		private func chooseChar(_ idx: Int, totalChars: Int) -> AttributedString {
			let sectionWidth = Double(totalChars) / Double(self.chars.count)
			let sectionIdx = min(
				chars.count - 1,
				Int(Double(idx) / sectionWidth)
			)

			return AttributedString("\(self.chars[sectionIdx])")
		}

		#if DEBUG
			@ObserveInjection var forceRedraw
		#endif
	}
}

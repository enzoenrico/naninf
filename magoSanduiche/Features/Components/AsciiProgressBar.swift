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
                    .font(.monocraft(size: 16))
					.frame(height: geo.size.height, alignment: .center)

			}
			.enableInjection()
		}

		private func calculateCharCount(for width: CGFloat) -> Int {
			max(1, Int(width / charWidth))
		}

		private func populateBar(charCount: Int) -> AttributedString {
			var attributedString = AttributedString()
			for i in 0..<charCount {
				let filledChar = i >= progress - 1 ? self.chars[1] : self.chars[0]
				let emptyChar = self.chars[3]
				let charVal = i <= progress ? filledChar : emptyChar

				var char = AttributedString(charVal)
				char.foregroundColor = i <= progress ? Color.accent : Color.gray
				attributedString += char
			}

			return attributedString
		}

		#if DEBUG
			@ObserveInjection var forceRedraw
		#endif
	} 
}

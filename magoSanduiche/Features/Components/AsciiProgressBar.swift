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
	var maxProgress: Int = 48 

	init(_ barType: BarTypes, progress: Int = 100) {
		self.barType = barType
		self.progress = progress
	}

	var body: some View {
		HStack(alignment: .center, spacing: -5) {
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

		var body: some View {
			Text(populateBar())
                .bold()
				.kerning(-1.5)
				.frame(maxWidth: .infinity)
		}

		private func populateBar() -> AttributedString {
			let clampedValue = max(0, min(progress, maxProgress))
			var attributedString = AttributedString()

			for _ in 0...clampedValue {
				var filledBar = AttributedString("|")
				filledBar.foregroundColor = Color.accent
				attributedString += filledBar
			}

			for _ in clampedValue...maxProgress {
				var emptyBar = AttributedString("|")
				emptyBar.foregroundColor = .gray
				attributedString += emptyBar
			}

			return attributedString
		}

		#if DEBUG
			@ObserveInjection var forceRedraw
		#endif
	}
}

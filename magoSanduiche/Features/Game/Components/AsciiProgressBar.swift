//
//  AsciiProgressBar.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import SwiftUI
import Foundation

enum BarTypes: String {
	case health
	case mana

	var label: String {
		switch self {
		case .health:
			String(localized: "nan_progressbar_hp")
		case .mana:
			String(localized: "nan_progressbar_mp")
		}
	}

	func color(progress: Int, maxProgress: Int) -> Color {
		switch self {
		case .health:
			progress <= maxProgress / 3 ? .terminalDanger : .accent
		case .mana:
			.terminalMana
		}
	}
}

struct AsciiProgressBar: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var barType: BarTypes
	var progress: Int
	var maxProgress: Int = 18

	init(_ barType: BarTypes, progress: Int = 2, maxProgress: Int = 18) {
		self.barType = barType
		self.progress = progress
		self.maxProgress = maxProgress
	}

	var body: some View {
		HStack(alignment: .center, spacing: 6) {
			Text(barType.label)
				.foregroundStyle(.accent)
				.font(.monocraft(relativeTo: .caption, weight: .semibold))

			Bar(
				barType: barType,
				progress: clampedProgress,
				maxProgress: maxProgress
			)

			Text("\(clampedProgress)/\(maxProgress)")
				.font(.monocraft(relativeTo: .caption2))
				.foregroundStyle(barColor)
				.monospacedDigit()
		}
		.frame(maxWidth: .infinity, maxHeight: 25)
		.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation), value: progress)
		.accessibilityLabel(String(format: String(localized: "nan_progressbar_a11y"), barType.label, clampedProgress, maxProgress))
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private var clampedProgress: Int {
		min(max(progress, 0), maxProgress)
	}

	private var barColor: Color {
		barType.color(progress: clampedProgress, maxProgress: maxProgress)
	}

	private struct Bar: View {
		let barType: BarTypes
		let progress: Int
		let maxProgress: Int

		private let chars = ["█", "▓", "▒", "░"]
		private let fontSize: CGFloat = 16
		private var charWidth: CGFloat { fontSize * 0.65 }

		var body: some View {
			GeometryReader { geo in
				let charCount = max(1, Int(geo.size.width / charWidth))
				Text(populateBar(charCount: charCount))
					.font(.monocraft(size: fontSize))
					.frame(height: geo.size.height, alignment: .center)
			}
			.enableInjection()
		}

		private func populateBar(charCount: Int) -> AttributedString {
			let filledCount = Int((Double(progress) / Double(maxProgress)) * Double(charCount))
			let barColor = barType.color(progress: progress, maxProgress: maxProgress)
			var attributedString = AttributedString()

			for index in 0..<charCount {
				let filledChar = index >= filledCount - 1 ? chars[1] : chars[0]
				let value = index < filledCount ? filledChar : chars[3]
				var char = AttributedString(value)
				char.foregroundColor = index < filledCount ? barColor : Color.terminalMutedText.opacity(0.55)
				attributedString += char
			}

			return attributedString
		}

		#if DEBUG
			@ObserveInjection var forceRedraw
		#endif
	}
}

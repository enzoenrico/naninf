//
//  SuggestedOptionsList.swift
//  magoSanduiche
//
//  Tappable DM suggestions shown above the text input.
//

import SwiftUI

#if canImport(UIKit)
	import UIKit
#endif

struct SuggestedOptionsList: View {
	let options: [String]
	let isDisabled: Bool
	let onSelect: (String) -> Void

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var expandedRowIndex: Int?

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(Array(options.enumerated()), id: \.offset) { index, option in
				SuggestedOptionRow(
					index: index,
					text: option,
					isDisabled: isDisabled,
					expandedRowIndex: $expandedRowIndex,
					onSelect: {
						expandedRowIndex = nil
						onSelect(option)
					}
				)
			}
		}
		.animation(
			TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
			value: expandedRowIndex
		)
		.accessibilityElement(children: .contain)
	}
}

// MARK: - Layout / measurement

#if canImport(UIKit)
	private enum SuggestedOptionLayout {
		static let rowMinHeight: CGFloat = 44
		/// Target height when a long option expands (larger than collapsed).
		static let expandedRowMinHeight: CGFloat = 128
		static let collapsedLineLimit = 3

		static func uiFontBody() -> UIFont {
			let size = UIFont.preferredFont(forTextStyle: .body).pointSize
			return UIFont(name: "Monocraft", size: size)
				?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
		}

		static func textExceedsLineLimit(_ text: String, maxWidth: CGFloat, maxLines: Int) -> Bool {
			guard maxWidth > 4, !text.isEmpty, maxLines > 0 else { return false }
			let font = uiFontBody()
			let attrs: [NSAttributedString.Key: Any] = [.font: font]
			let size = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
			let rect = (text as NSString).boundingRect(
				with: size,
				options: [.usesLineFragmentOrigin, .usesFontLeading],
				attributes: attrs,
				context: nil
			)
			let maxAllowed = font.lineHeight * CGFloat(maxLines) + font.leading + 1
			return rect.height > maxAllowed
		}

		static func expandedScrollMaxHeight() -> CGFloat {
			min(260, max(expandedRowMinHeight + 24, UIScreen.main.bounds.height * 0.32))
		}
	}
#else
	private enum SuggestedOptionLayout {
		static let rowMinHeight: CGFloat = 44
		/// Target height when a long option expands (larger than collapsed).
		static let expandedRowMinHeight: CGFloat = 128
		static let collapsedLineLimit = 3

		static func textExceedsLineLimit(_ text: String, maxWidth: CGFloat, maxLines: Int) -> Bool {
			_ = (maxWidth, maxLines)
			return text.count > 140
		}

		static func expandedScrollMaxHeight() -> CGFloat {
			180
		}
	}
#endif

// MARK: - Row

private struct SuggestedOptionRow: View {
	let index: Int
	let text: String
	let isDisabled: Bool
	@Binding var expandedRowIndex: Int?
	let onSelect: () -> Void

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var measuredCardWidth: CGFloat = 0

	private let horizontalPadding: CGFloat = 10

	private var foregroundColor: Color {
		isDisabled ? Color.terminalMutedText : Color.accent
	}

	private var borderColor: Color {
		isDisabled ? Color.accent.opacity(0.35) : Color.accentBorderIdle
	}

	private var textColumnMaxWidth: CGFloat {
		max(1, measuredCardWidth - horizontalPadding * 2)
	}

	private var needsRevealStep: Bool {
		if measuredCardWidth > 50 {
			return SuggestedOptionLayout.textExceedsLineLimit(
				text,
				maxWidth: textColumnMaxWidth,
				maxLines: SuggestedOptionLayout.collapsedLineLimit
			)
		}
		let roughLines = 1 + text.filter(\.isNewline).count
		return text.count > 140 || roughLines >= 4
	}

	private var isExpanded: Bool {
		expandedRowIndex == index
	}

	var body: some View {
		card
			.frame(maxWidth: .infinity, alignment: .leading)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
				value: isExpanded
			)
			.onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
				measuredCardWidth = width
			}
	}

	private func optionLabel(lineLimit: Int?) -> some View {
		HStack(alignment: .top, spacing: 8) {
			Text(">")
				.font(.monocraft(relativeTo: .headline, weight: .semibold))
				.foregroundStyle(foregroundColor)
			Text(text)
				.font(.monocraft(relativeTo: .body))
				.multilineTextAlignment(.leading)
				.lineLimit(lineLimit)
				.truncationMode(.tail)
				.frame(maxWidth: .infinity, alignment: .leading)
				.foregroundStyle(foregroundColor)
		}
		.padding(.horizontal, horizontalPadding)
		.padding(.vertical, 12)
	}

	private var card: some View {
		Button {
			handleTap()
		} label: {
			cardContent
		}
		.buttonStyle(SuggestedOptionButtonStyle())
		.disabled(isDisabled)
		.accessibilityLabel(text)
		.optionalAccessibilityHint(
			needsRevealStep && !isExpanded
				? String(localized: "nan_suggested_action_expand_a11y_hint")
				: nil
		)
		.accessibilityElement(children: isExpanded ? .contain : .ignore)
	}

	private var cardContent: some View {
		Group {
			if needsRevealStep, isExpanded {
				ScrollView(.vertical, showsIndicators: true) {
					optionLabel(lineLimit: nil)
				}
				.transition(
					TerminalMotion.panelTransition(reduceMotion: reduceMotion, edge: .bottom)
				)
			} else {
				optionLabel(
					lineLimit: needsRevealStep ? SuggestedOptionLayout.collapsedLineLimit : nil
				)
				.transition(
					TerminalMotion.panelTransition(reduceMotion: reduceMotion, edge: .bottom)
				)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.frame(
			minHeight: isExpanded
				? SuggestedOptionLayout.expandedRowMinHeight
				: SuggestedOptionLayout.rowMinHeight,
			maxHeight: isExpanded ? SuggestedOptionLayout.expandedScrollMaxHeight() : nil,
			alignment: .leading
		)
		.clipped()
		.drawBorder(nil, color: borderColor, lineWidth: 1)
	}

	private func handleTap() {
		guard !isDisabled else { return }
		if needsRevealStep {
			guard !isExpanded else { return }
			TerminalMotion.perform(reduceMotion: reduceMotion) {
				expandedRowIndex = index
			}
		} else {
			onSelect()
		}
	}
}

// MARK: - Accessibility

private extension View {
	@ViewBuilder
	func optionalAccessibilityHint(_ hint: String?) -> some View {
		if let hint, !hint.isEmpty {
			self.accessibilityHint(hint)
		} else {
			self
		}
	}
}

// MARK: - Button styles

private struct SuggestedOptionButtonStyle: ButtonStyle {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.opacity(configuration.isPressed ? 0.92 : 1)
			.scaleEffect(configuration.isPressed && !reduceMotion ? TerminalMotion.pressScale : 1)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation),
				value: configuration.isPressed
			)
	}
}

private struct SuggestedOptionConfirmButtonStyle: ButtonStyle {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.opacity(configuration.isPressed ? 0.92 : 1)
			.scaleEffect(configuration.isPressed && !reduceMotion ? TerminalMotion.pressScale : 1)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation),
				value: configuration.isPressed
			)
	}
}

#if DEBUG
	#Preview {
		SuggestedOptionsList(
			options: [
				"Cast a defensive spell to prepare for an attack and hold your ground while the shadows close in.",
				"Advance cautiously toward the shadowy figure to confront it.",
			],
			isDisabled: false,
			onSelect: { _ in }
		)
		.padding()
		.preferredColorScheme(.dark)
	}
#endif

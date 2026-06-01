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
	@Binding var selectedIndex: Int?
	let maxExpandedRowHeight: CGFloat?
	let onExpansionChange: ((Bool) -> Void)?

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var expandedRowIndex: Int?

	init(
		options: [String],
		isDisabled: Bool,
		selectedIndex: Binding<Int?>,
		maxExpandedRowHeight: CGFloat? = nil,
		onExpansionChange: ((Bool) -> Void)? = nil
	) {
		self.options = options
		self.isDisabled = isDisabled
		self._selectedIndex = selectedIndex
		self.maxExpandedRowHeight = maxExpandedRowHeight
		self.onExpansionChange = onExpansionChange
	}

	private var effectiveExpandedRowMaxHeight: CGFloat {
		let screenCap = SuggestedOptionLayout.expandedScrollMaxHeight()
		guard let maxExpandedRowHeight else { return screenCap }
		return min(screenCap, max(SuggestedOptionLayout.rowMinHeight, maxExpandedRowHeight))
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(Array(options.enumerated()), id: \.offset) { index, option in
				SuggestedOptionRow(
					index: index,
					text: option,
					isDisabled: isDisabled,
					maxExpandedRowHeight: effectiveExpandedRowMaxHeight,
					selectedIndex: $selectedIndex,
					expandedRowIndex: $expandedRowIndex
				)
			}
		}
		.animation(
			TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
			value: expandedRowIndex
		)
		.animation(
			TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
			value: selectedIndex
		)
		.onChange(of: expandedRowIndex) { _, newValue in
			onExpansionChange?(newValue != nil)
		}
		.onChange(of: options.count) { _, _ in
			if let selectedIndex, selectedIndex >= options.count {
				self.selectedIndex = nil
				expandedRowIndex = nil
			}
		}
		.accessibilityElement(children: .contain)
	}
}

// MARK: - Layout / measurement

#if canImport(UIKit)
	enum SuggestedOptionLayout {
		static let rowMinHeight: CGFloat = 44
		static let labelVerticalPadding: CGFloat = 24
		static let labelHorizontalPadding: CGFloat = 10
		static let labelPromptReserve: CGFloat = 28
		static let collapsedLineLimit = 3

		static func uiFontBody() -> UIFont {
			let size = UIFont.preferredFont(forTextStyle: .body).pointSize
			return UIFont(name: "Monocraft", size: size)
				?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
		}

		static func textExceedsLineLimit(_ text: String, maxWidth: CGFloat, maxLines: Int) -> Bool {
			guard maxWidth > 4, !text.isEmpty, maxLines > 0 else { return false }
			let font = uiFontBody()
			let maxAllowed = font.lineHeight * CGFloat(maxLines) + font.leading + 1
			return measuredTextHeight(text, maxWidth: maxWidth) > maxAllowed
		}

		static func measuredTextHeight(_ text: String, maxWidth: CGFloat) -> CGFloat {
			guard maxWidth > 4, !text.isEmpty else { return 0 }
			let font = uiFontBody()
			let attrs: [NSAttributedString.Key: Any] = [.font: font]
			let size = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
			let rect = (text as NSString).boundingRect(
				with: size,
				options: [.usesLineFragmentOrigin, .usesFontLeading],
				attributes: attrs,
				context: nil
			)
			return ceil(rect.height)
		}

		static func optionLabelHeight(text: String, cardWidth: CGFloat) -> CGFloat {
			let textWidth = max(1, cardWidth - labelHorizontalPadding * 2 - labelPromptReserve)
			let textHeight = measuredTextHeight(text, maxWidth: textWidth)
			return max(rowMinHeight, textHeight + labelVerticalPadding)
		}

		static func expandedScrollMaxHeight() -> CGFloat {
			min(260, UIScreen.main.bounds.height * 0.32)
		}
	}
#else
	enum SuggestedOptionLayout {
		static let rowMinHeight: CGFloat = 44
		static let labelVerticalPadding: CGFloat = 24
		static let labelHorizontalPadding: CGFloat = 10
		static let labelPromptReserve: CGFloat = 28
		static let collapsedLineLimit = 3

		static func textExceedsLineLimit(_ text: String, maxWidth: CGFloat, maxLines: Int) -> Bool {
			_ = (maxWidth, maxLines)
			return text.count > 140
		}

		static func optionLabelHeight(text: String, cardWidth: CGFloat) -> CGFloat {
			let roughLines = max(1, 1 + text.filter(\.isNewline).count, (text.count + 39) / 40)
			return max(rowMinHeight, CGFloat(roughLines) * 20 + labelVerticalPadding)
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
	let maxExpandedRowHeight: CGFloat
	@Binding var selectedIndex: Int?
	@Binding var expandedRowIndex: Int?

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var measuredCardWidth: CGFloat = 0

	private let horizontalPadding: CGFloat = 10

	private var isSelected: Bool {
		selectedIndex == index
	}

	private var foregroundColor: Color {
		if isDisabled { return Color.terminalMutedText }
		return isSelected ? Color.terminalWarning : Color.accent
	}

	private var borderColor: Color {
		if isDisabled { return Color.accent.opacity(0.35) }
		return isSelected ? Color.terminalWarning : Color.accentBorderIdle
	}

	private var borderLineWidth: CGFloat {
		isSelected ? 2 : 1
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

	private var expandedLabelHeight: CGFloat {
		SuggestedOptionLayout.optionLabelHeight(text: text, cardWidth: measuredCardWidth)
	}

	private var needsScrollWhenExpanded: Bool {
		expandedLabelHeight > maxExpandedRowHeight
	}

	var body: some View {
		card
			.frame(maxWidth: .infinity, alignment: .leading)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
				value: isExpanded
			)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
				value: isSelected
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
		.optionalAccessibilityHint(accessibilityHint)
		.accessibilityElement(children: isExpanded ? .contain : .ignore)
	}

	private var cardContent: some View {
		Group {
			if needsRevealStep, isExpanded {
				Group {
					if needsScrollWhenExpanded {
						ScrollView(.vertical, showsIndicators: true) {
							optionLabel(lineLimit: nil)
						}
						.frame(height: maxExpandedRowHeight, alignment: .top)
					} else {
						optionLabel(lineLimit: nil)
							.fixedSize(horizontal: false, vertical: true)
					}
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
			minHeight: isExpanded ? nil : SuggestedOptionLayout.rowMinHeight,
			maxHeight: isExpanded && needsScrollWhenExpanded ? maxExpandedRowHeight : nil,
			alignment: .leading
		)
		.fixedSize(horizontal: false, vertical: isExpanded && !needsScrollWhenExpanded)
		.clipped()
		.drawBorder(nil, color: borderColor, lineWidth: borderLineWidth)
	}

	private var accessibilityHint: String? {
		if isSelected {
			return String(localized: "nan_suggested_action_selected_a11y_hint")
		}
		if needsRevealStep, !isExpanded {
			return String(localized: "nan_suggested_action_expand_a11y_hint")
		}
		return nil
	}

	private func handleTap() {
		guard !isDisabled else { return }

		TerminalMotion.perform(reduceMotion: reduceMotion) {
			if isSelected {
				selectedIndex = nil
				if expandedRowIndex == index {
					expandedRowIndex = nil
				}
			} else {
				selectedIndex = index
				if needsRevealStep {
					expandedRowIndex = index
				} else {
					expandedRowIndex = nil
				}
			}
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
		@Previewable @State var selectedIndex: Int?

		SuggestedOptionsList(
			options: [
				"Cast a defensive spell to prepare for an attack and hold your ground while the shadows close in.",
				"Advance cautiously toward the shadowy figure to confront it.",
			],
			isDisabled: false,
			selectedIndex: $selectedIndex
		)
		.padding()
		.preferredColorScheme(.dark)
	}
#endif

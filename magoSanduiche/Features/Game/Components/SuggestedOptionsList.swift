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
		.accessibilityElement(children: .contain)
	}
}

// MARK: - Layout / measurement

#if canImport(UIKit)
	private enum SuggestedOptionLayout {
		static let rowMinHeight: CGFloat = 44
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
			min(220, max(120, UIScreen.main.bounds.height * 0.28))
		}
	}
#else
	private enum SuggestedOptionLayout {
		static let rowMinHeight: CGFloat = 44
		static let collapsedLineLimit = 3

		static func textExceedsLineLimit(_ text: String, maxWidth: CGFloat, maxLines: Int) -> Bool {
			_ = (maxWidth, maxLines)
			return text.count > 140
		}

		static func expandedScrollMaxHeight() -> CGFloat {
			160
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
		Group {
			if needsRevealStep, isExpanded {
				expandedCard
			} else {
				collapsedCard
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
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

	private var collapsedCard: some View {
		Button {
			guard !isDisabled else { return }
			if needsRevealStep {
				expandedRowIndex = index
			} else {
				onSelect()
			}
		} label: {
			optionLabel(
				lineLimit: needsRevealStep ? SuggestedOptionLayout.collapsedLineLimit : nil
			)
			.frame(maxWidth: .infinity, minHeight: SuggestedOptionLayout.rowMinHeight, alignment: .leading)
			.drawBorder(nil, color: borderColor, lineWidth: 1)
		}
		.buttonStyle(SuggestedOptionButtonStyle())
		.disabled(isDisabled)
		.accessibilityLabel(text)
		.optionalAccessibilityHint(
			needsRevealStep ? String(localized: "nan_suggested_action_expand_a11y_hint") : nil
		)
	}

	private var expandedCard: some View {
		VStack(alignment: .leading, spacing: 0) {
			ScrollView {
				optionLabel(lineLimit: nil)
			}
			.frame(
				minHeight: SuggestedOptionLayout.rowMinHeight,
				maxHeight: SuggestedOptionLayout.expandedScrollMaxHeight()
			)

			// Rectangle()
			// 	.fill(Color.accent.opacity(0.35))
			// 	.frame(height: 1)
			// 	.accessibilityHidden(true)

			// Button {
			// 	guard !isDisabled else { return }
			// 	onSelect()
			// } label: {
			// 	Text(String(localized: "nan_suggested_action_tap_again"))
			// 		.font(.monocraft(relativeTo: .callout, weight: .semibold))
			// 		.foregroundStyle(foregroundColor)
			// 		.frame(maxWidth: .infinity, minHeight: SuggestedOptionLayout.rowMinHeight)
			// }
			// .buttonStyle(SuggestedOptionConfirmButtonStyle())
			// .disabled(isDisabled)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.drawBorder(nil, color: borderColor, lineWidth: 1)
    .animation(.bouncy())
		.accessibilityElement(children: .contain)
		.accessibilityLabel(text)
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

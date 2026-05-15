//
//  ContextualButton.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

import Foundation
import SwiftUI

struct ContextualButton: View {
	var type: GameAction
	var isInputVisible = false
	var isLoading = false
	var phase: GameUIPhase = .ready
	var action: () -> Void

	var body: some View {
		Button {
			guard !isLoading else { return }
			action()
		} label: {
			HStack(spacing: 8) {
				if isLoading {
					TerminalGlyphLoader(
						style: .spinner,
						textStyle: .headline,
						weight: .bold,
						color: .terminalWarning
					)
				} else {
					Image(type.buttonImage.rawValue)
						.renderingMode(.template)
						.foregroundStyle(Color.accent)
				}

				Text(buttonTitle)
					.font(.monocraft(relativeTo: .headline, weight: .semibold))
					.foregroundStyle(Color.accent)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 14)
			.frame(maxWidth: .infinity)
		}
		.disabled(isLoading)
		.buttonStyle(TerminalButtonStyle(isLoading: isLoading))
		.accessibilityLabel(buttonAccessibilityTitle)
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private var buttonTitle: String {
		if isLoading {
			switch phase {
			case .rollingDice:
				String(localized: "nan_button_loading_fate_rolling")
			case .awaitingDungeonMaster:
				String(localized: "nan_button_loading_story")
			default:
				String(localized: "nan_button_loading_processing")
			}
		} else {
			type.buttonTitle(isInputVisible: isInputVisible)
		}
	}

	private var buttonAccessibilityTitle: String {
		if isLoading {
			switch phase {
			case .rollingDice:
				String(localized: "nan_a11y_button_fate_rolling")
			case .awaitingDungeonMaster:
				String(localized: "nan_a11y_button_writing_story")
			default:
				String(localized: "nan_a11y_button_processing")
			}
		} else {
			switch type {
			case .write:
				isInputVisible
					? String(localized: "nan_a11y_action_send_command")
					: String(localized: "nan_a11y_action_write_command")
			case .roll:
				String(localized: "nan_a11y_action_roll_d20")
			}
		}
	}
}

private struct TerminalButtonStyle: ButtonStyle {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let isLoading: Bool

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.drawBorder(
				nil,
				color: isLoading ? Color.terminalWarning : Color.accent,
				lineWidth: configuration.isPressed ? 3 : 2
			)
			.scaleEffect(configuration.isPressed ? TerminalMotion.pressScale : 1)
			.opacity(isLoading ? 0.78 : 1)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation),
				value: configuration.isPressed)
	}
}

struct TintedIconLabelStyle: LabelStyle {
	var iconTintColor: Color

	func makeBody(configuration: Configuration) -> some View {
		HStack {
			configuration.icon
				.foregroundStyle(iconTintColor)
			configuration.title
		}
	}
}

extension LabelStyle where Self == TintedIconLabelStyle {
	static func tintedIcon(color: Color) -> TintedIconLabelStyle {
		TintedIconLabelStyle(iconTintColor: color)
	}
}

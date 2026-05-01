//
//  ContextualButton.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

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
					LoadingDots()
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
		.accessibilityLabel(buttonTitle.replacingOccurrences(of: "> ", with: ""))
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private var buttonTitle: String {
		if isLoading {
			switch phase {
			case .rollingDice:
				"> FATE IS ROLLING"
			case .awaitingDungeonMaster:
				"> WRITING THE STORY"
			default:
				"> PROCESSING"
			}
		} else {
			type.buttonTitle(isInputVisible: isInputVisible)
		}
	}
}

private struct LoadingDots: View {
	@State private var activeDot = 0

	var body: some View {
		HStack(spacing: 2) {
			ForEach(0..<3, id: \.self) { index in
				Text(".")
					.font(.monocraft(relativeTo: .headline, weight: .bold))
					.opacity(activeDot == index ? 1 : 0.28)
			}
		}
		.task {
			while !Task.isCancelled {
				try? await Task.sleep(for: .milliseconds(180))
				activeDot = (activeDot + 1) % 3
			}
		}
	}
}

private struct TerminalButtonStyle: ButtonStyle {
	let isLoading: Bool

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.drawBorder(
				nil,
				color: isLoading ? Color.terminalWarning : Color.accent,
				lineWidth: configuration.isPressed ? 3 : 2
			)
			.scaleEffect(configuration.isPressed ? 0.985 : 1)
			.opacity(isLoading ? 0.78 : 1)
			.shadow(color: Color.accent.opacity(configuration.isPressed ? 0.18 : 0.35), radius: 10)
			.animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

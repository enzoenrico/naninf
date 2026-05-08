//
//  TerminalSubtleButtonStyle.swift
//  magoSanduiche
//
//  Lightweight press feedback for buttons that are not bordered primaries —
//  back affordances, selection cards, modal dismiss. Mirrors the project
//  press scale (0.985) and `TerminalMotion.quickPressAnimation` so every
//  tappable surface feels responsive without competing with the bordered
//  primaries.
//

import SwiftUI

struct TerminalSubtleButtonStyle: ButtonStyle {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.scaleEffect(configuration.isPressed && !reduceMotion ? TerminalMotion.pressScale : 1)
			.opacity(configuration.isPressed ? 0.92 : 1)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation),
				value: configuration.isPressed
			)
	}
}

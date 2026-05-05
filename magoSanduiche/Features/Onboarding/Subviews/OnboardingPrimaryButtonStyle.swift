//
//  OnboardingPrimaryButtonStyle.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct OnboardingPrimaryButtonStyle: ButtonStyle {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.foregroundStyle(Color.accent)
			.drawBorder(
				nil,
				color: .accent,
				lineWidth: configuration.isPressed ? 3 : 2
			)
			.scaleEffect(configuration.isPressed ? 0.985 : 1)
			.shadow(color: Color.accent.opacity(0.28), radius: 10)
			.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation), value: configuration.isPressed)
	}
}

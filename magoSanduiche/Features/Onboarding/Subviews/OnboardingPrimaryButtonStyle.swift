//
//  OnboardingPrimaryButtonStyle.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct OnboardingPrimaryButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.foregroundStyle(Color.accent)
//            .background(Color.backgroundColor)
            .drawBorder(
                nil,
                color: .accent,
                lineWidth: configuration.isPressed ? 3 : 2
            )
			.scaleEffect(configuration.isPressed ? 0.985 : 1)
			.shadow(color: Color.accent.opacity(0.28), radius: 10)
			.animation(.easeOut(duration: 0.12), value: configuration.isPressed)
	}
}

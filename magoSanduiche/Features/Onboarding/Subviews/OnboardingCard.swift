//
//  OnboardingCard.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct OnboardingCard: View {
	let option: OnboardingOption
	var isSelected = false

	var body: some View {
		VStack(spacing: 16) {
			Image(option.image)
				.resizable()
				.interpolation(.none)
				.scaledToFit()
				.frame(height: 150)
				.foregroundStyle(isSelected ? Color.terminalWarning : Color.accent)
				.shadow(color: Color.accent.opacity(0.35), radius: 12)

			Text(option.title)
				.font(.monocraft(relativeTo: .title2, weight: .semibold))
				.multilineTextAlignment(.center)
				.foregroundStyle(isSelected ? Color.terminalWarning : Color.accent)

			Text(option.subtitle)
				.font(.monocraft(relativeTo: .body))
				.multilineTextAlignment(.center)
				.foregroundStyle(Color.terminalMutedText)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.drawBorder(nil, color: isSelected ? .terminalWarning : .accentBorderActive, lineWidth: isSelected ? 2 : 1)
	}
}

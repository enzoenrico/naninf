//
//  OnboardingCard.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct OnboardingCard: View {
	let page: OnboardingPage

	var body: some View {
		VStack(spacing: 16) {
			Image(page.image)
				.resizable()
				.interpolation(.none)
				.scaledToFit()
				.frame(height: 150)
				.foregroundStyle(.accent)
				.shadow(color: Color.accent.opacity(0.35), radius: 12)

			Text(page.title)
				.font(.monocraft(relativeTo: .title2, weight: .semibold))
				.multilineTextAlignment(.center)
				.foregroundStyle(Color.accent)

			Text(page.message)
				.font(.monocraft(relativeTo: .body))
				.multilineTextAlignment(.center)
				.foregroundStyle(Color.terminalMutedText)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

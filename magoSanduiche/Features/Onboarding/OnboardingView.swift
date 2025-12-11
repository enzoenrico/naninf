//
//  OnboardingView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct OnboardingView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@State private var currentIndex = 0

	private let pages: [OnboardingPage] = [
		.init(
			title: "Welcome, player.",
			message:
				"Every choice you make shapes the story. As a lone mage in a dangerous dungeon, you must explore it's contents to it's fullest and make out victorious.",
			image: .cards
		),
		.init(
			title: "A world truly yours.",
			message:
				"Do anything, from casting a light spell to stopping for a sandwich, the dungeon master talks to you and adapts the world and story to give you all of the freedoom you can want.",
			image: .ink
		),
		.init(
			title: "Will you survive the dungeon?",
			message:
				"Embrace the randomness and possibility, become the one who wins against the dungeon.",
			image: .dice
		)
	]

	var body: some View {
		@Bindable var coordinator = coordinator
		VStack(spacing: 24) {
			TabView(selection: $currentIndex) {
				ForEach(pages.indices, id: \.self) { index in
					OnboardingCard(page: pages[index])
						.tag(index)
						.padding(.horizontal, 16)
				}
			}
			.tabViewStyle(.page)
			.indexViewStyle(.page(backgroundDisplayMode: .always))

			Button(action: handlePrimaryAction) {
				Text(primaryButtonTitle)
					.font(.monocraft(relativeTo: .headline, weight: .semibold))
					.frame(maxWidth: .infinity)
					.padding(.vertical, 12)
			}
			.tint(.accent)
			.drawBorder()
			.padding(.horizontal, 24)
		}
		.padding(.vertical, 32)
		.background(Color.background)
		.enableInjection()
	}

	private var primaryButtonTitle: String {
		currentIndex == pages.count - 1 ? "Start Adventure" : "Next"
	}

	private func handlePrimaryAction() {
		if currentIndex < pages.count - 1 {
			withAnimation { currentIndex += 1 }
		} else {
			coordinator.navigate(to: .gameDetail)
		}
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

private struct OnboardingPage: Identifiable {
	let id = UUID()
	let title: String
	let message: String
	let image: ImageResource
}

private struct OnboardingCard: View {
	let page: OnboardingPage

	var body: some View {
		VStack(spacing: 16) {
			Image(page.image)
				.resizable()
				.interpolation(.none)
				.scaledToFit()
				.frame(height: 150)
				.foregroundStyle(.accent)

			Text(page.title)
				.font(.monocraft(relativeTo: .title2, weight: .semibold))
				.multilineTextAlignment(.center)

			Text(page.message)
				.font(.monocraft(relativeTo: .body))
				.multilineTextAlignment(.center)
				.foregroundStyle(.secondary)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

//
//  OnboardingViewModel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import Foundation

@Observable
final class OnboardingViewModel {
	var currentIndex = 0

	let pages: [OnboardingPage] = [
		.init(
			title: "Welcome, player.",
			message:
				"Every choice shapes the story. As a lone mage in a dangerous dungeon, you must explore its secrets and make it out victorious.",
			image: .cards,
			command: "wake up in the sealed hall"
		),
		.init(
			title: "A world truly yours.",
			message:
				"Do anything, from casting a light spell to stopping for a sandwich. The dungeon master adapts the world around your choices.",
			image: .ink,
			command: "cast light and inspect the walls"
		),
		.init(
			title: "Will you survive the dungeon?",
			message:
				"Embrace the randomness and possibility, become the one who wins against the dungeon.",
			image: .dice,
			command: "take the first step"
		),
	]

	var primaryButtonTitle: String {
		isOnFinalPage ? "> EXECUTE FIRST COMMAND" : "> NEXT TRANSMISSION"
	}

	var currentPage: OnboardingPage {
		pages[currentIndex]
	}

	var isOnFinalPage: Bool {
		currentIndex == pages.count - 1
	}

	func advance() -> Bool {
		guard !isOnFinalPage else { return true }
		currentIndex += 1
		return false
	}
}

//
//  NavigationCoordinator.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

enum AppRoute: Hashable {
	case onboarding
	case gameDetail
}

@Observable
final class AppCoordinator {
	var path = NavigationPath()
	var isImageCollapsed = true
	var isContextualInputVisible = false
	var hasCompletedInitialText = false
    var showActionButton: Bool = false

	func toggleImageVisibility() {
		if !isContextualInputVisible { isImageCollapsed.toggle() }
	}

	func handleContextualAction(_ type: ContextualActions, onSubmit: () -> Bool) {
		switch type {
		case .write:
			if isContextualInputVisible {
				let didSubmit = onSubmit()
				if didSubmit { resetContextualInputState() }
			} else {
				isContextualInputVisible = true
				isImageCollapsed = true
			}
		case .roll:
			break
		}
	}

	private func resetContextualInputState() {
		isContextualInputVisible = false
		isImageCollapsed = true
	}

	func handleTypewriterCompletion() {
		withAnimation(.easeInOut) {
			hasCompletedInitialText = true
			isImageCollapsed = false
            showActionButton = true
		}
	}

	func navigate(to route: AppRoute) {
		path.append(route)
	}

	func back() {
		guard !path.isEmpty else { return }
		path.removeLast()
	}

	func popToRoot() {
		path.removeLast(path.count)
	}
}

struct AppCoordinatorView: View {
	@Environment(AppCoordinator.self) private var coordinator

	var body: some View {
		@Bindable var coordinator = coordinator
		NavigationStack(path: $coordinator.path) {
			OnboardingView()
				.navigationDestination(for: AppRoute.self) { route in
					switch route {
					case .onboarding:
						// OnboardingView()
						var gameVm = GameViewModel()
						GameView(vm: gameVm)
					case .gameDetail:
						GameView()
					}
				}
		}
		.environment(coordinator)
		.background(Color.background)
	}
}

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
	private var _isUpdatingState = false
	
	var isImageCollapsed = true {
		didSet {
			guard !_isUpdatingState else { return }
			// When image is opened (collapsed = false), hide contextual input
			if !isImageCollapsed && isContextualInputVisible {
				_isUpdatingState = true
				isContextualInputVisible = false
				_isUpdatingState = false
			}
		}
	}
	
	var isContextualInputVisible = false {
		didSet {
			guard !_isUpdatingState else { return }
			// Contextual input can only be visible when image is collapsed
			// If trying to show input when image is open, collapse the image first
			if isContextualInputVisible && !isImageCollapsed {
				_isUpdatingState = true
				isImageCollapsed = true
				_isUpdatingState = false
			}
		}
	}
	
	var isDicePromptVisible = false
	var hasCompletedInitialText = false
	var showActionButton: Bool = false

	func toggleImageVisibility() {
		if !isContextualInputVisible {
			isImageCollapsed = !isImageCollapsed
		}
	}

	func handleContextualAction(_ type: ContextualActions, onSubmit: () -> Bool) {
		switch type {
		case .write:
			if isContextualInputVisible {
				let didSubmit = onSubmit()
				if didSubmit { resetContextualInputState() }
			} else {
				isContextualInputVisible = true
				isDicePromptVisible = false
				isImageCollapsed = true
			}
		case .roll:
			if isContextualInputVisible {
				let didSubmit = onSubmit()
				if didSubmit { resetContextualInputState() }
			} else {
				isContextualInputVisible = false
				isDicePromptVisible = true
				isImageCollapsed = false
			}
		}
	}

	private func resetContextualInputState() {
		isContextualInputVisible = false
		isDicePromptVisible = false
		isImageCollapsed = true
	}

	func handleTypewriterCompletion() {
		withAnimation(.easeInOut) {
			hasCompletedInitialText = true
			isImageCollapsed = false
			showActionButton = true
		}
	}

	func toggleImage() {
		if hasCompletedInitialText {
			withAnimation(.easeInOut) {
				if isImageCollapsed {
					// Opening image - hide contextual input
					isImageCollapsed = false
				} else {
					// Closing image - can show contextual input if it was visible before
					isImageCollapsed = true
				}
			}
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
						GameView()
					case .gameDetail:
						GameView()
					}
				}
		}
		.environment(coordinator)
		.background(Color.background)
	}
}

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
						//OnboardingView()
						GameView()
					case .gameDetail:
						GameView()
					}
				}
				.environment(coordinator)
		}
		.background(Color.background)
	}
}

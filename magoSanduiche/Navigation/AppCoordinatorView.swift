//
//  AppCoordinatorView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct AppCoordinatorView: View {
	@Environment(AppCoordinator.self) private var coordinator

	var body: some View {
		@Bindable var coordinator = coordinator

		NavigationStack(path: $coordinator.path) {
			OnboardingView()
				.navigationDestination(for: AppRoute.self) { route in
					switch route {
					case .onboarding:
						OnboardingView()
					case .game:
						GameView()
					}
				}
		}
		.background(Color.background)
	}
}

//
//  AppCoordinatorView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI
import Foundation

struct AppCoordinatorView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@AppStorage("hasUnlockedFullGame") private var hasUnlockedFullGame = false

	var body: some View {
		@Bindable var coordinator = coordinator

		NavigationStack(path: $coordinator.path) {
			Group {
				if hasUnlockedFullGame {
					PlayerHomeView()
				} else {
					OnboardingView()
				}
			}
			.transition(TerminalMotion.panelTransition(reduceMotion: reduceMotion, edge: .bottom))
			.navigationDestination(for: AppRoute.self) { route in
				switch route {
				case .home:
					PlayerHomeView()
				case .onboarding:
					OnboardingView()
				case .game:
					if hasUnlockedFullGame {
						GameView()
					} else {
						OnboardingView()
					}
				case .profile:
					ProfileView()
				case .load:
					LoadRunView()
				case .about:
					AboutView()
				}
			}
		}
		.background(Color.background)
		.overlay(alignment: .bottomTrailing) {
			#if DEBUG
				if hasUnlockedFullGame {
					Button {
						TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
							hasUnlockedFullGame = false
							coordinator.popToRoot()
						}
					} label: {
						Text("nan_debug_onboarding_button")
							.font(.monocraft(relativeTo: .caption, weight: .semibold))
							.foregroundStyle(Color.terminalWarning)
							.padding(.horizontal, 10)
							.padding(.vertical, 8)
					}
					.buttonStyle(.plain)
					.background(Color.terminalSurface.opacity(0.96))
					.drawBorder(nil, color: .terminalWarning, lineWidth: 1)
					.padding(16)
					.accessibilityLabel(String(localized: "nan_debug_onboarding_a11y"))
				}
			#endif
		}
	}
}

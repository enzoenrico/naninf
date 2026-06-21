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
	@Environment(AuthSessionStore.self) private var authSessionStore
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
	@AppStorage("hasUnlockedFullGame") private var hasUnlockedFullGame = false

	var body: some View {
		@Bindable var coordinator = coordinator

		NavigationStack(path: $coordinator.path) {
			rootScreen
			.transition(TerminalMotion.panelTransition(reduceMotion: reduceMotion, edge: .bottom))
			.navigationDestination(for: AppRoute.self) { route in
				switch route {
				case .home:
					gatedHomeScreen
				case .onboarding:
					OnboardingView()
				case .game:
					if canEnterHome {
						GameView()
					} else {
						rootScreen
					}
				case .profile:
					if canEnterHome {
						ProfileView()
					} else {
						rootScreen
					}
				case .load:
					if canEnterHome {
						LoadRunView()
					} else {
						rootScreen
					}
				case .about:
					if canEnterHome {
						AboutView()
					} else {
						rootScreen
					}
				}
			}
		}
		.background(Color.background)
		.task {
			#if DEBUG
				coordinator.applyUITestInitialRouteIfNeeded()
			#endif
		}
		.overlay(alignment: .bottomTrailing) {
			#if DEBUG
				if hasFinishedOnboarding && !UITestConfiguration.isActive {
					Button {
						TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
							hasCompletedOnboarding = false
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

	private var hasFinishedOnboarding: Bool {
		hasCompletedOnboarding || hasUnlockedFullGame
	}

	private var canEnterHome: Bool {
		hasFinishedOnboarding && authSessionStore.isAuthenticated
	}

	@ViewBuilder
	private var rootScreen: some View {
		if !hasFinishedOnboarding {
			OnboardingView()
		} else {
			gatedHomeScreen
		}
	}

	@ViewBuilder
	private var gatedHomeScreen: some View {
		if authSessionStore.isAuthenticated {
			PlayerHomeView()
		} else {
			AuthView()
		}
	}
}

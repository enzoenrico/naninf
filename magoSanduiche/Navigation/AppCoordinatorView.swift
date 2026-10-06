//
//  AppCoordinatorView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import FoundationModels
import SwiftUI
import Foundation

struct AppCoordinatorView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Environment(AuthSessionStore.self) private var authSessionStore
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
	@AppStorage("hasUnlockedFullGame") private var hasUnlockedFullGame = false
	@State private var cloudModel = PrivateCloudComputeLanguageModel()

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
					if canEnterPlay {
						GameView()
					} else {
						rootScreen
					}
				case .profile:
					if canEnterPlay {
						ProfileView()
					} else {
						rootScreen
					}
				case .load:
					if canEnterPlay {
						LoadRunView()
					} else {
						rootScreen
					}
				case .about:
					if canEnterPlay {
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

	private var canEnterPlay: Bool {
		canEnterHome && cloudAccess == .granted
	}

	private var cloudAccess: PrivateCloudAccess {
		#if DEBUG
			if UITestConfiguration.isActive || ScriptedNarrator.isEnabledByDefaults {
				return .granted
			}
		#endif
		return PrivateCloudAccess(availability: cloudModel.availability)
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
			authenticatedScreen
		} else {
			AuthView()
		}
	}

	@ViewBuilder
	private var authenticatedScreen: some View {
		switch cloudAccess {
		case .granted:
			PlayerHomeView()
		case .denied(let reason):
			PrivateCloudAccessGate(reason: reason)
		}
	}
}

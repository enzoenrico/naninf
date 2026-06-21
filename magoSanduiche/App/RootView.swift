//
//  RootView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI
import Foundation

struct AppStartupGate: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var hasCompletedStartup: Bool = {
		#if DEBUG
			return UITestConfiguration.skipsBoot
		#else
			return false
		#endif
	}()

	var body: some View {
		Group {
			if hasCompletedStartup {
				RootView()
					.transition(TerminalMotion.panelTransition(reduceMotion: reduceMotion, edge: .bottom))
			} else {
				StartupBootView {
					TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.bootCrossfadeAnimation) {
						hasCompletedStartup = true
					}
				}
				.transition(.opacity)
			}
		}
	}
}

struct RootView: View {
	@State private var coordinator = AppCoordinator()

	var body: some View {
		AppCoordinatorView()
			.environment(coordinator)
	}
}

private struct StartupBootView: View {
	let onFinished: () -> Void

	private var bootMessages: [String] {
		[
			"NAN-DOS 1.0",
			"Copyright (C) 1986 Sandwich Wizard Systems",
			"",
			"C:\\MAGO> BOOT DUNGEON.EXE",
			String(localized: "nan_boot_loading_memory"),
			String(localized: "nan_boot_ok_dungeon_master"),
			String(localized: "nan_boot_ok_d20_driver"),
			String(localized: "nan_boot_ok_hp_mp"),
			String(localized: "nan_boot_ok_sandwich"),
			"",
			"C:\\NAN> OPEN_GATE",
			"READY.",
		]
	}

	var body: some View {
		GeometryReader { proxy in
			ZStack(alignment: .topLeading) {
				Color.background
				LinearGradient(
					colors: [
						Color.terminalMana.opacity(0.12),
						Color.clear,
						Color.terminalWarning.opacity(0.08),
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)

				BootScanlineOverlay(opacity: 0.22, spacing: 3, lineHeight: 1)

				VStack(alignment: .leading, spacing: 20) {
					VStack(alignment: .leading, spacing: 6) {
						Text("MAGO-DOS")
							.font(.monocraft(relativeTo: .title2, weight: .bold))
							.foregroundStyle(Color.accent)
							.shadow(color: Color.accent.opacity(0.65), radius: 8)

						Text("nan_startup_subtitle")
							.font(.monocraft(relativeTo: .caption, weight: .semibold))
							.foregroundStyle(Color.terminalMana)
					}

					BootLogView(
						messages: bootMessages,
						lineDelay: .milliseconds(245),
						blankLineDelay: .milliseconds(120),
						completionDelay: .milliseconds(420),
						lineSpacing: 6,
						textStyle: .callout,
						cursorColor: .terminalWarning,
						showsPromptPrefix: false,
						onFinished: onFinished
					)
					.shadow(color: Color.accent.opacity(0.34), radius: 7)

					Spacer(minLength: 0)
				}
				.padding(.horizontal, 24)
				.padding(.top, max(proxy.safeAreaInsets.top + 26, 42))
				.padding(.bottom, max(proxy.safeAreaInsets.bottom + 24, 36))
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			}
			.ignoresSafeArea()
		}
		.accessibilityAddTraits(.isModal)
	}
}

#Preview {
    StartupBootView(onFinished: { })
}

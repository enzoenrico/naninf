//
//  PlayerHomeView.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI
import Foundation

#if canImport(UIKit)
	import UIKit
#endif

struct PlayerHomeView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@State private var focusedItemID: String = HomeMenuItem.menu.first?.id ?? "play"

	private let menu = HomeMenuItem.menu
	private var tagline: String { String(localized: "nan_home_tagline") }

	private var focusedMenuKey: String {
		menu.first(where: { $0.id == focusedItemID })?.key ?? "P"
	}

	var body: some View {
		AppLayout(
			background: .gradient,
			contentPadding: EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0)
		) {
			CRTReveal {
				VStack(spacing: 18) {
					HomeHeroBanner(tagline: tagline)
						.padding(.horizontal, 20)

					menuList

					Spacer(minLength: 0)
				}
			}
		}
		.safeAreaInset(edge: .top, spacing: 0) {
			topStrip
		}
		.safeAreaInset(edge: .bottom, spacing: 0) {
			footerStrip
		}
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	// MARK: - Sections

	private var topStrip: some View {
		HStack(spacing: 8) {
			Text("MAGO-DOS")
				.font(.monocraft(relativeTo: .caption, weight: .bold))
				.foregroundStyle(Color.accent)
			Text("//")
				.font(.monocraft(relativeTo: .caption, weight: .bold))
				.foregroundStyle(Color.terminalMutedText)
			Text("nan_home_session_ready")
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(Color.terminalMana)

			Spacer()

			TerminalGlyphLoader(style: .blocks, textStyle: .caption, color: .terminalWarning)
				.accessibilityHidden(true)
		}
		.padding(.horizontal, 20)
		.padding(.top, 10)
		.padding(.bottom, 8)
		.background(Color.background.opacity(0.96))
	}

	private var menuList: some View {
		VStack(spacing: 10) {
			ForEach(Array(menu.enumerated()), id: \.element.id) { index, item in
				HomeMenuRow(
					item: item,
					isFocused: focusedItemID == item.id,
					revealIndex: index
				) {
					handleSelect(item)
				}
				.simultaneousGesture(
					TapGesture().onEnded {
						focus(item)
					}
				)
			}
		}
		.padding(.horizontal, 20)
	}

	private var footerStrip: some View {
		HStack(spacing: 10) {
			Text(String(format: String(localized: "nan_home_footer_version"), appVersion))
				.font(.monocraft(relativeTo: .caption2, weight: .semibold))
				.foregroundStyle(Color.terminalMutedText)
			Spacer()
			Text(String(format: String(localized: "nan_home_footer_selected"), focusedMenuKey))
				.font(.monocraft(relativeTo: .caption2, weight: .semibold))
				.foregroundStyle(Color.terminalMutedText)
				.lineLimit(1)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 10)
		.background(Color.background.opacity(0.96))
	}

	// MARK: - Actions

	private func handleSelect(_ item: HomeMenuItem) {
		focus(item)
		triggerImpactHaptic()
		AppAnalytics.capture("home_menu_item_selected", properties: [
			"item_id": item.id,
			"route": String(describing: item.route)
		])
		TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
			coordinator.navigate(to: item.route)
		}
	}

	private func focus(_ item: HomeMenuItem) {
		guard focusedItemID != item.id else { return }
		triggerSelectionHaptic()
		TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
			focusedItemID = item.id
		}
	}

	private func triggerSelectionHaptic() {
		guard !reduceMotion else { return }
		#if canImport(UIKit)
			let generator = UISelectionFeedbackGenerator()
			generator.selectionChanged()
		#endif
	}

	private func triggerImpactHaptic() {
		guard !reduceMotion else { return }
		#if canImport(UIKit)
			let generator = UIImpactFeedbackGenerator(style: .soft)
			generator.impactOccurred()
		#endif
	}

	private var appVersion: String {
		let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
		return short ?? "0.1"
	}
}

#Preview {
	PlayerHomeView()
		.environment(AppCoordinator())
}

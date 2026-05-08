//
//  HomeMenuRow.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI
import Foundation

struct HomeMenuItem: Identifiable, Hashable {
	let id: String
	let key: String
	let title: String
	let detail: String
	let route: AppRoute
	let accent: Color

	var voiceOverHint: String {
		String(format: String(localized: "nan_home_menu_voiceover_hint"), title, detail)
	}
}

extension HomeMenuItem {
	static let menu: [HomeMenuItem] = [
		.init(
			id: "play",
			key: "P",
			title: String(localized: "nan_menu_play_title"),
			detail: String(localized: "nan_menu_play_detail"),
			route: .game,
			accent: .accent
		),
		.init(
			id: "load",
			key: "L",
			title: String(localized: "nan_menu_load_title"),
			detail: String(localized: "nan_menu_load_detail"),
			route: .load,
			accent: .terminalMana
		),
		.init(
			id: "stats",
			key: "S",
			title: String(localized: "nan_menu_stats_title"),
			detail: String(localized: "nan_menu_stats_detail"),
			route: .profile,
			accent: .terminalWarning
		),
		.init(
			id: "about",
			key: "A",
			title: String(localized: "nan_menu_about_title"),
			detail: String(localized: "nan_menu_about_detail"),
			route: .about,
			accent: .terminalMutedText
		),
	]
}

struct HomeMenuRow: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let item: HomeMenuItem
	let isFocused: Bool
	var revealIndex: Int = 0
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(alignment: .center, spacing: 10) {
				caretSlot

				CRTRevealText(
					text: "[\(item.key)]",
					font: .monocraft(relativeTo: .headline, weight: .bold),
					color: isFocused ? Color.terminalWarning : item.accent.opacity(0.85),
					delay: rowDelay
				)

				CRTRevealText(
					text: item.title,
					font: .monocraft(relativeTo: .headline, weight: .semibold),
					color: isFocused ? Color.accent : item.accent,
					delay: rowDelay + .milliseconds(40)
				)

				Spacer(minLength: 12)

				CRTRevealText(
					text: item.detail,
					font: .monocraft(relativeTo: .caption, weight: .semibold),
					color: isFocused ? Color.terminalWarning : Color.terminalMutedText,
					lineLimit: 1,
					delay: rowDelay + .milliseconds(120)
				)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 12)
			.frame(minHeight: 48, alignment: .leading)
			.contentShape(Rectangle())
		}
		.buttonStyle(HomeMenuRowButtonStyle(accent: item.accent, isFocused: isFocused))
		.accessibilityLabel("\(item.title), \(item.detail)")
		.accessibilityHint(item.voiceOverHint)
	}

	private var rowDelay: Duration {
		.milliseconds(80 * revealIndex)
	}

	@ViewBuilder
	private var caretSlot: some View {
		ZStack(alignment: .leading) {
			Text(" ")
				.font(.monocraft(relativeTo: .headline, weight: .bold))
				.frame(width: 16, alignment: .leading)

			if isFocused {
				HStack(spacing: 0) {
					Text(">")
						.font(.monocraft(relativeTo: .headline, weight: .bold))
						.foregroundStyle(Color.terminalWarning)
				}
				.frame(width: 16, alignment: .leading)
				.accessibilityHidden(true)
			}
		}
		.frame(width: 16)
	}
}

private struct HomeMenuRowButtonStyle: ButtonStyle {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let accent: Color
	let isFocused: Bool

	func makeBody(configuration: Configuration) -> some View {
		let borderColor = isFocused ? Color.accent : accent.opacity(0.55)
		let lineWidth: CGFloat = configuration.isPressed ? 3 : (isFocused ? 2 : 1)

		return configuration.label
			.background(isFocused ? Color.terminalActiveSurface : Color.terminalSurface)
			.drawBorder(nil, color: borderColor, lineWidth: lineWidth, animate: true)
			.scaleEffect(configuration.isPressed ? TerminalMotion.pressScale : 1)
			.shadow(color: borderColor.opacity(isFocused ? 0.28 : 0), radius: isFocused ? 10 : 0)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation),
				value: configuration.isPressed
			)
			.animation(
				TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
				value: isFocused
			)
	}
}

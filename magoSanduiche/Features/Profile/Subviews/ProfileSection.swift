//
//  ProfileSection.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI
import Foundation

struct ProfileKeyValueRow: View {
	let key: String
	let value: String
	var valueColor: Color = .accent

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			Text("> \(key)")
				.font(.monocraft(relativeTo: .caption, weight: .bold))
				.foregroundStyle(Color.terminalMutedText)
				.frame(minWidth: 110, alignment: .leading)
			Text(value)
				.font(.monocraft(relativeTo: .callout, weight: .semibold))
				.foregroundStyle(valueColor)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
		.accessibilityElement(children: .combine)
	}
}

struct ProfileCounterRow: View {
	let key: String
	let value: Int
	var isLoading: Bool

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			Text("> \(key)")
				.font(.monocraft(relativeTo: .caption, weight: .bold))
				.foregroundStyle(Color.terminalMutedText)
				.frame(minWidth: 130, alignment: .leading)

			if isLoading {
				TerminalGlyphLoader(style: .blocks, textStyle: .callout, color: .terminalWarning)
					.accessibilityHidden(true)
			} else {
				Text(String(value))
					.font(.monocraft(relativeTo: .callout, weight: .bold))
					.foregroundStyle(Color.accent)
					.contentTransition(.numericText(value: Double(value)))
			}

			Spacer(minLength: 0)
		}
		.accessibilityElement(children: .combine)
		.accessibilityLabel(
			isLoading
				? "\(key): \(String(localized: "nan_profile_counter_loading"))"
				: "\(key): \(String(value))"
		)
	}
}

struct ProfileSection<Content: View>: View {
	let title: String
	let accent: Color
	@ViewBuilder var content: () -> Content

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			content()
		}
		.padding(14)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.terminalSurface)
		.drawBorder("> \(title)", color: accent, lineWidth: 1)
	}
}

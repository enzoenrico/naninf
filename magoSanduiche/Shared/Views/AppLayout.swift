//
//  AppLayout.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI

/// Visual treatment used behind a screen's content. Centralizes the recurring
/// backdrop variants used across the app so individual views stay consistent.
enum AppBackgroundStyle {
	/// Flat `Color.background` fill. Used by document-style screens (About, Profile, LoadRun).
	case solid
	/// `Color.background` plus the diagonal accent/mana wash. Used by hub-style
	/// screens (Onboarding, PlayerHome).
	case gradient
	/// `TerminalBackdrop` with scanline grid. Reserved for the live game session.
	case terminalGrid
}

extension EdgeInsets {
	static let appLayoutDefault = EdgeInsets(top: 16, leading: 20, bottom: 24, trailing: 20)
}

/// Hoisted so SwiftUI doesn't reallocate the gradient on every `AppLayout` body pass.
private let hubGradient = LinearGradient(
	colors: [
		Color.accent.opacity(0.10),
		Color.clear,
		Color.terminalMana.opacity(0.08),
	],
	startPoint: .topLeading,
	endPoint: .bottomTrailing
)

/// Global layout template applied around every top-level screen. Centralizes
/// background, content padding, navigation chrome hiding, and the hot-reload
/// injection hook so individual views only worry about their content.
struct AppLayout<Content: View>: View {
	var background: AppBackgroundStyle = .solid
	var contentPadding: EdgeInsets = .appLayoutDefault
	var scrollable: Bool = false
	@ViewBuilder var content: () -> Content

	var body: some View {
		ZStack {
			backgroundLayer
				.ignoresSafeArea()

			contentContainer
		}
		.navigationBarBackButtonHidden(true)
		.toolbar(.hidden, for: .navigationBar)
		.enableInjection()
	}

	@ViewBuilder
	private var backgroundLayer: some View {
		switch background {
		case .solid:
			Color.background
		case .gradient:
			ZStack {
				Color.background
				hubGradient
			}
		case .terminalGrid:
			TerminalBackdrop()
		}
	}

	@ViewBuilder
	private var contentContainer: some View {
		if scrollable {
			// `ScrollView` already proposes infinite height to its content; adding
			// `maxHeight: .infinity` here causes flex thrash, especially with `Spacer`s.
			ScrollView {
				content()
					.padding(contentPadding)
					.frame(maxWidth: .infinity, alignment: .top)
			}
		} else {
			content()
				.padding(contentPadding)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		}
	}
}

#Preview("Solid") {
	AppLayout(background: .solid, scrollable: true) {
		VStack(alignment: .leading, spacing: 12) {
			Text("> APP.LAYOUT")
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(Color.terminalMana)
			Text("Solid background")
				.font(.monocraft(relativeTo: .title3, weight: .bold))
				.foregroundStyle(Color.accent)
		}
	}
}

#Preview("Gradient") {
	AppLayout(background: .gradient) {
		Text("Gradient background")
			.font(.monocraft(relativeTo: .title3, weight: .bold))
			.foregroundStyle(Color.accent)
	}
}

#Preview("Terminal Grid") {
	AppLayout(background: .terminalGrid) {
		Text("Terminal grid background")
			.font(.monocraft(relativeTo: .title3, weight: .bold))
			.foregroundStyle(Color.accent)
	}
}

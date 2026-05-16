//
//  TerminalMotion.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI

enum TerminalMotion {
	static let cursorSymbol = "▌"
	static let blockCursorSymbol = "█"
	static let scrambleGlyphs = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ$#@|&*~`.<>/?")

	static let cursorInterval: Duration = .milliseconds(520)
	static let loaderInterval: Duration = .milliseconds(180)
	static let dotsInterval: Duration = .milliseconds(220)
	static let typewriterStepDelay: Duration = .milliseconds(5)
	static let bootLineAnimation = Animation.easeOut(duration: 0.15)
	static let textAnimation = Animation.easeOut(duration: 0.18)
	static let panelAnimation = Animation.snappy(duration: 0.28)
	static let quickPressAnimation = Animation.easeOut(duration: 0.12)
	/// Boot screen → app shell crossfade. Slightly slower than `panelAnimation`
	/// because the entire root view is being swapped underneath.
	static let bootCrossfadeAnimation = Animation.easeOut(duration: 0.35)
	/// D20 blackout after scramble; strong ease-out (see design-eng motion notes).
	static let diceFadeAnimation = Animation.timingCurve(
		0.23, 1, 0.32, 1,
		duration: Double(DiceRollRevealTiming.fadeOutMillis) / 1000)
	static let diceFadeAnimationReduceMotion = Animation.easeOut(
		duration: Double(DiceRollRevealTiming.fadeOutMillisReduceMotion) / 1000)
	/// Final number “popup” after suspense.
	static let diceRevealAnimation = Animation.timingCurve(
		0.23, 1, 0.32, 1,
		duration: Double(DiceRollRevealTiming.bamRevealMillis) / 1000)
	static let diceRevealAnimationReduceMotion = Animation.easeOut(
		duration: Double(DiceRollRevealTiming.bamRevealMillisReduceMotion) / 1000)

	static func diceFadeAnimation(reduceMotion: Bool) -> Animation {
		reduceMotion ? diceFadeAnimationReduceMotion : diceFadeAnimation
	}

	static func diceRevealAnimation(reduceMotion: Bool) -> Animation {
		reduceMotion ? diceRevealAnimationReduceMotion : diceRevealAnimation
	}
	/// Onboarding option toggle. Snappier than `panelAnimation` so multi-select
	/// taps feel immediate even when several rows update in sequence.
	static let optionToggleAnimation = Animation.snappy(duration: 0.22)

	/// Press scale used by every bordered or subtle button style. Keeping it as
	/// a single constant prevents drift (0.98 vs 0.985 vs 0.99) across styles.
	static let pressScale: CGFloat = 0.985

	static func animation(_ reduceMotion: Bool, _ animation: Animation) -> Animation? {
		reduceMotion ? nil : animation
	}

	static func perform(
		reduceMotion: Bool,
		animation: Animation = TerminalMotion.panelAnimation,
		_ changes: () -> Void
	) {
		if reduceMotion {
			changes()
		} else {
			withAnimation(animation) {
				changes()
			}
		}
	}

	static func panelTransition(reduceMotion: Bool, edge: Edge = .bottom) -> AnyTransition {
		guard !reduceMotion else { return .opacity }
		return terminalOffsetTransition(edge: edge, distance: 8)
			.combined(with: .opacity)
	}

	static func textTransition(reduceMotion: Bool, edge: Edge = .bottom) -> AnyTransition {
		guard !reduceMotion else { return .opacity }
		return terminalOffsetTransition(edge: edge, distance: 4)
			.combined(with: .opacity)
	}

	private static func terminalOffsetTransition(edge: Edge, distance: CGFloat) -> AnyTransition {
		let insertion = TerminalOffsetEffect(edge: edge, distance: distance, opacity: 0)
		let removal = TerminalOffsetEffect(edge: edge.opposite, distance: distance, opacity: 0)
		return .asymmetric(
			insertion: .modifier(active: insertion, identity: TerminalOffsetEffect(edge: edge, distance: 0, opacity: 1)),
			removal: .modifier(active: removal, identity: TerminalOffsetEffect(edge: edge, distance: 0, opacity: 1))
		)
	}
}

enum TerminalGlyphLoaderStyle {
	case dots
	case spinner
	case blocks

	var frames: [String] {
		switch self {
		case .dots:
			[".", "..", "..."]
		case .spinner:
			["|", "/", "-", "\\"]
		case .blocks:
			["░", "▒", "▓", "█", "▓", "▒"]
		}
	}

	var staticFrame: String {
		switch self {
		case .dots:
			"..."
		case .spinner:
			"|"
		case .blocks:
			"█"
		}
	}

	var interval: Duration {
		switch self {
		case .dots:
			TerminalMotion.dotsInterval
		case .spinner, .blocks:
			TerminalMotion.loaderInterval
		}
	}

	var frameWidth: CGFloat {
		switch self {
		case .dots:
			24
		case .spinner:
			12
		case .blocks:
			16
		}
	}
}

struct TerminalGlyphLoader: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var style: TerminalGlyphLoaderStyle = .spinner
	var textStyle: Font.TextStyle = .caption
	var weight: Font.Weight = .bold
	var color: Color = .terminalWarning
	var alignment: Alignment = .leading

	@State private var activeFrame = 0

	var body: some View {
		Text(currentFrame)
			.font(.monocraft(relativeTo: textStyle, weight: weight))
			.foregroundStyle(color)
			.frame(width: style.frameWidth, alignment: alignment)
			.accessibilityHidden(true)
			.task(id: reduceMotion) {
				await runLoader()
			}
	}

	private var currentFrame: String {
		guard !reduceMotion else { return style.staticFrame }
		return style.frames[activeFrame]
	}

	private func runLoader() async {
		activeFrame = 0
		guard !reduceMotion else { return }

		while !Task.isCancelled {
			try? await Task.sleep(for: style.interval)
			guard !Task.isCancelled else { return }
			activeFrame = (activeFrame + 1) % style.frames.count
		}
	}
}

struct TerminalCursor: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var symbol = TerminalMotion.cursorSymbol
	var textStyle: Font.TextStyle = .callout
	var weight: Font.Weight = .bold
	var color: Color = .accent
	var dimOpacity = 0.2

	@State private var isVisible = true

	var body: some View {
		Text(symbol)
			.font(.monocraft(relativeTo: textStyle, weight: weight))
			.foregroundStyle(color)
			.opacity(cursorOpacity)
			.accessibilityHidden(true)
			.task(id: reduceMotion) {
				await blinkCursor()
			}
	}

	private var cursorOpacity: Double {
		guard !reduceMotion else { return 1 }
		return isVisible ? 1 : dimOpacity
	}

	private func blinkCursor() async {
		isVisible = true
		guard !reduceMotion else { return }

		while !Task.isCancelled {
			try? await Task.sleep(for: TerminalMotion.cursorInterval)
			guard !Task.isCancelled else { return }
			isVisible.toggle()
		}
	}
}

extension View {
	func terminalPanelTransition(edge: Edge = .bottom) -> some View {
		modifier(TerminalPanelTransitionModifier(edge: edge))
	}

	func terminalTextTransition(edge: Edge = .bottom) -> some View {
		modifier(TerminalTextTransitionModifier(edge: edge))
	}
}

private struct TerminalPanelTransitionModifier: ViewModifier {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let edge: Edge

	func body(content: Content) -> some View {
		content.transition(TerminalMotion.panelTransition(reduceMotion: reduceMotion, edge: edge))
	}
}

private struct TerminalTextTransitionModifier: ViewModifier {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let edge: Edge

	func body(content: Content) -> some View {
		content.transition(TerminalMotion.textTransition(reduceMotion: reduceMotion, edge: edge))
	}
}

private struct TerminalOffsetEffect: ViewModifier {
	let edge: Edge
	let distance: CGFloat
	let opacity: Double

	func body(content: Content) -> some View {
		content
			.opacity(opacity)
			.offset(x: offset.width, y: offset.height)
	}

	private var offset: CGSize {
		switch edge {
		case .top:
			CGSize(width: 0, height: -distance)
		case .bottom:
			CGSize(width: 0, height: distance)
		case .leading:
			CGSize(width: -distance, height: 0)
		case .trailing:
			CGSize(width: distance, height: 0)
		}
	}
}

private extension Edge {
	var opposite: Edge {
		switch self {
		case .top:
			.bottom
		case .bottom:
			.top
		case .leading:
			.trailing
		case .trailing:
			.leading
		}
	}
}

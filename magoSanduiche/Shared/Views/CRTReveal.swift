//
//  CRTReveal.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI

// MARK: - Phase model

enum CRTRevealStage: Equatable {
	case idle
	case drawingBorders
	case typingText
	case complete
}

// Stage and border progress are exposed as separate environment keys so a
// continuously-animating `borderProgress` only invalidates the views that
// actually read it (the borders), not every `CRTRevealText` in the subtree.

private struct CRTRevealStageKey: EnvironmentKey {
	static let defaultValue: CRTRevealStage = .complete
}

private struct CRTRevealBorderProgressKey: EnvironmentKey {
	static let defaultValue: Double = 1
}

extension EnvironmentValues {
	var crtRevealStage: CRTRevealStage {
		get { self[CRTRevealStageKey.self] }
		set { self[CRTRevealStageKey.self] = newValue }
	}

	var crtRevealBorderProgress: Double {
		get { self[CRTRevealBorderProgressKey.self] }
		set { self[CRTRevealBorderProgressKey.self] = newValue }
	}
}

// MARK: - Scene wrapper

/// Drives a single shared CRT-style reveal timeline (borders pen-trace, then
/// text types in) and exposes the current stage and border progress via
/// `\.crtRevealStage` / `\.crtRevealBorderProgress` so children
/// (`drawBorder(animate: true)`, `CRTRevealText`) animate in lockstep without
/// their own bespoke schedulers.
struct CRTReveal<Content: View>: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var borderDuration: Duration = .milliseconds(450)
	var textDuration: Duration = .milliseconds(700)
	var interStageGap: Duration = .milliseconds(80)
	@ViewBuilder var content: () -> Content

	@State private var stage: CRTRevealStage = .idle
	@State private var borderProgress: Double = 0

	var body: some View {
		content()
			.environment(\.crtRevealStage, stage)
			.environment(\.crtRevealBorderProgress, borderProgress)
			.task(id: reduceMotion) {
				await runTimeline()
			}
	}

	private func runTimeline() async {
		guard !reduceMotion else {
			stage = .complete
			borderProgress = 1
			return
		}

		stage = .idle
		borderProgress = 0
		// Yield once so SwiftUI applies the reset before we kick off the
		// animated transition; otherwise the trim animation may be skipped.
		await Task.yield()
		guard !Task.isCancelled else { return }

		stage = .drawingBorders
		withAnimation(.linear(duration: borderDuration.timeIntervalSeconds)) {
			borderProgress = 1
		}

		try? await Task.sleep(for: borderDuration + interStageGap)
		guard !Task.isCancelled else { return }

		stage = .typingText

		try? await Task.sleep(for: textDuration)
		guard !Task.isCancelled else { return }

		stage = .complete
	}
}

// MARK: - Reveal-aware text

/// `Text`-equivalent that reads the ambient `CRTRevealStage` and reveals its
/// content character-by-character once the scene reaches `.typingText`. When
/// rendered outside a `CRTReveal` (or when reduce-motion is on) it draws the
/// full text immediately, so it is safe to use anywhere.
struct CRTRevealText: View {
	@Environment(\.crtRevealStage) private var stage
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let text: String
	var font: Font = .monocraft()
	var color: Color = .accent
	var alignment: TextAlignment = .leading
	var lineLimit: Int? = nil
	var lineSpacing: CGFloat = 0
	var delay: Duration = .zero
	var charInterval: Duration = .milliseconds(18)
	var scrambleSwaps: Int = 1
	var showsCursorWhileTyping: Bool = false

	@State private var visibleChars: [Character] = []
	@State private var cursorVisible = true

	var body: some View {
		ZStack(alignment: layoutAlignment) {
			// Hidden full-text twin reserves the final layout so surrounding
			// views don't reflow as characters appear.
			Text(text)
				.hidden()
				.accessibilityHidden(true)

			Text(displayedText)
				.multilineTextAlignment(alignment)
		}
		.font(font)
		.foregroundStyle(color)
		.lineSpacing(lineSpacing)
		.lineLimit(lineLimit)
		.accessibilityLabel(text)
		.task(id: stage) {
			await runTyping()
		}
		.task(id: stage) {
			await blinkCursor()
		}
	}

	// MARK: - Display

	private var layoutAlignment: Alignment {
		switch alignment {
		case .leading: .topLeading
		case .center: .top
		case .trailing: .topTrailing
		}
	}

	private var displayedText: String {
		if reduceMotion || stage != .typingText {
			return stage == .complete || reduceMotion ? text : ""
		}
		let base = String(visibleChars)
		guard showsCursorWhileTyping, visibleChars.count < text.count else {
			return base
		}
		return base + (cursorVisible ? TerminalMotion.cursorSymbol : " ")
	}

	// MARK: - Tasks

	private func runTyping() async {
		guard stage == .typingText, !reduceMotion else { return }
		await typeOut()
	}

	private func typeOut() async {
		visibleChars = []

		if delay > .zero {
			try? await Task.sleep(for: delay)
			guard !Task.isCancelled else { return }
		}

		for char in text {
			for _ in 0 ..< max(0, scrambleSwaps) {
				let glyph = TerminalMotion.scrambleGlyphs.randomElement() ?? char
				visibleChars.append(glyph)
				try? await Task.sleep(for: TerminalMotion.typewriterStepDelay)
				guard !Task.isCancelled else { return }
				visibleChars.removeLast()
			}
			visibleChars.append(char)
			try? await Task.sleep(for: charInterval)
			guard !Task.isCancelled else { return }
		}
	}

	// Tied to `stage` so the loop exits when typing completes (the parent
	// task is cancelled and a new one early-returns), avoiding a perpetual
	// background toggle on the home screen.
	private func blinkCursor() async {
		guard showsCursorWhileTyping, stage == .typingText, !reduceMotion else {
			cursorVisible = false
			return
		}

		while !Task.isCancelled {
			try? await Task.sleep(for: TerminalMotion.cursorInterval)
			guard !Task.isCancelled else { return }
			cursorVisible.toggle()
		}
	}
}

// MARK: - Helpers

private extension Duration {
	// `withAnimation(.linear(duration:))` expects seconds as a Double;
	// `Duration` only exposes integer seconds + attoseconds, so recombine.
	var timeIntervalSeconds: TimeInterval {
		let comps = components
		return TimeInterval(comps.seconds) + TimeInterval(comps.attoseconds) / 1e18
	}
}

// MARK: - Previews

#Preview("CRTReveal: full demo") {
	CRTReveal {
		VStack(alignment: .leading, spacing: 16) {
			CRTRevealText(
				text: "> NAN.SYS / SHELL READY",
				font: .monocraft(relativeTo: .caption, weight: .semibold),
				color: .terminalMana
			)

			CRTRevealText(
				text: "MAGO-DOS",
				font: .monocraft(relativeTo: .title2, weight: .bold),
				color: .accent,
				delay: .milliseconds(40)
			)

			CRTRevealText(
				text: "> A DUNGEON OF QUESTIONABLE SANDWICHES_",
				font: .monocraft(relativeTo: .callout, weight: .semibold),
				color: .terminalWarning,
				delay: .milliseconds(120),
				showsCursorWhileTyping: true
			)
		}
		.padding(20)
		.frame(maxWidth: .infinity, alignment: .leading)
		.drawBorder("> NAN.SYS", color: .accent, lineWidth: 1, animate: true)
		.padding(20)
	}
	.frame(maxWidth: .infinity, maxHeight: .infinity)
	.background(Color.background)
}

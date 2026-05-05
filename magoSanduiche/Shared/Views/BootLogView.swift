//
//  BootLogView.swift
//  magoSanduiche
//
//  Created by Cursor on 03/05/26.
//

import SwiftUI

struct BootLogView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let messages: [String]
	var lineDelay: Duration = .milliseconds(320)
	var blankLineDelay: Duration = .milliseconds(160)
	var completionDelay: Duration = .milliseconds(220)
	var lineSpacing: CGFloat = 4
	var textStyle: Font.TextStyle = .caption
	var cursorColor: Color = .accent
	var showsPromptPrefix = true
	var onFinished: (() -> Void)?

	@State private var bootLines: [String] = []
	@State private var hasStarted = false
	@State private var hasCompleted = false

	var body: some View {
		VStack(alignment: .leading, spacing: lineSpacing) {
			ForEach(Array(bootLines.enumerated()), id: \.offset) { index, line in
				BootLogLineView(
					line: line,
					isFirstLine: index == 0,
					textStyle: textStyle,
					showsPromptPrefix: showsPromptPrefix
				)
					.terminalTextTransition(edge: .bottom)
			}

			if !hasCompleted {
				TerminalCursor(
					symbol: TerminalMotion.blockCursorSymbol,
					textStyle: textStyle,
					weight: .semibold,
					color: cursorColor,
					dimOpacity: 0
				)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.task {
			await runBootSequence()
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityText)
	}

	private var accessibilityText: String {
		messages.filter { !$0.isEmpty }.joined(separator: ". ")
	}

	private func runBootSequence() async {
		guard !hasStarted else { return }
		hasStarted = true

		guard !reduceMotion else {
			bootLines = messages
			await finishSequence(after: .milliseconds(120))
			return
		}

		bootLines = []
		for message in messages {
			try? await Task.sleep(for: message.isEmpty ? blankLineDelay : lineDelay)
			guard !Task.isCancelled else { return }

			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.bootLineAnimation) {
				bootLines.append(message)
			}
		}

		await finishSequence(after: completionDelay)
	}

	private func finishSequence(after delay: Duration) async {
		try? await Task.sleep(for: delay)
		guard !Task.isCancelled else { return }
		guard !hasCompleted else { return }

		hasCompleted = true
		onFinished?()
	}
}

struct BootScanlineOverlay: View {
	var opacity: Double = 0.16
	var spacing: CGFloat = 4
	var lineHeight: CGFloat = 1

	var body: some View {
		Canvas { context, size in
			var y: CGFloat = 0

			while y < size.height {
				let rect = CGRect(x: 0, y: y, width: size.width, height: lineHeight)
				context.fill(Path(rect), with: .color(.black.opacity(opacity)))
				y += spacing
			}
		}
		.allowsHitTesting(false)
	}
}

private struct BootLogLineView: View {
	let line: String
	let isFirstLine: Bool
	let textStyle: Font.TextStyle
	let showsPromptPrefix: Bool

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 0) {
			prefix
			content
		}
		.font(.monocraft(relativeTo: textStyle, weight: lineWeight))
	}

	@ViewBuilder
	private var prefix: some View {
		if line.isEmpty {
			Text(showsPromptPrefix ? "  " : "")
		} else if isFirstLine && showsPromptPrefix {
			Text("> ")
				.foregroundStyle(Color.terminalWarning)
		} else if line.hasPrefix("[OK]") {
			EmptyView()
		} else {
			Text(showsPromptPrefix ? "  " : "")
				.foregroundStyle(Color.terminalMutedText)
		}
	}

	@ViewBuilder
	private var content: some View {
		if line.isEmpty {
			Text(" ")
		} else if line.hasPrefix("[OK]") {
			Text("[")
				.foregroundStyle(Color.terminalMutedText)
				+ Text("OK")
				.foregroundStyle(Color.accent)
				+ Text("]")
				.foregroundStyle(Color.terminalMutedText)
				+ Text(String(line.dropFirst(4)))
				.foregroundStyle(Color.accent.opacity(0.72))
		} else if line.hasSuffix("...") || line.hasPrefix("C:\\") {
			Text(line)
				.foregroundStyle(Color.terminalMana)
		} else if isFirstLine {
			Text(line)
				.foregroundStyle(Color.accent)
		} else {
			Text(line)
				.foregroundStyle(lineColor)
		}
	}

	private var lineColor: Color {
		if line.localizedCaseInsensitiveContains("gate")
			|| line.localizedCaseInsensitiveContains("welcome")
			|| line.localizedCaseInsensitiveContains("sandwich")
			|| line.localizedCaseInsensitiveContains("ready")
		{
			return .terminalWarning
		}

		return .terminalMutedText
	}

	private var lineWeight: Font.Weight {
		isFirstLine ? .bold : .regular
	}
}


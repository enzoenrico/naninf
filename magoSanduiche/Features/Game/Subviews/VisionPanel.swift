//
//  VisionPanel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
	import UIKit
#endif

struct VisionPanel: View {
	let displayMode: VisionDisplayMode
	let isStoryLoading: Bool
	let isVisionLoading: Bool
	var generationPercent: Int?
	let phase: GameUIPhase

	private var showsStoryOverlay: Bool {
		isStoryLoading && !isVisionLoading
	}

	private var showsVisionSpinner: Bool {
		isVisionLoading && displayMode.recalledPrompt == nil
	}

	var body: some View {
		ZStack(alignment: .topLeading) {
			if showsVisionSpinner {
				AsciiVisionSpinner(percent: generationPercent)
			} else {
				mediaContent
					.frame(maxWidth: .infinity)
					.opacity(showsStoryOverlay ? 0.55 : 1)

				if showsStoryOverlay {
					VisionLoadingOverlay()
						.padding(10)
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
				}
			}
		}
		.frame(maxWidth: .infinity)
		.fixedSize(horizontal: false, vertical: true)
		.drawBorder(nil, color: .terminalMana, lineWidth: 1, animate: true, glowPreset: .chrome)
		.clipped()
		.accessibilityLabel(accessibilityLabel)
		.accessibilityHint(String(localized: "nan_vision_a11y_hint_collapse"))
	}

	private var accessibilityLabel: String {
		if let generationPercent, isVisionLoading {
			return String(format: String(localized: "nan_vision_collapsed_generating_a11y"), generationPercent)
		}
		if isVisionLoading || isStoryLoading {
			return String(localized: "nan_vision_a11y_loading")
		}
		return String(localized: "nan_vision_a11y_ready")
	}

	@ViewBuilder
	private var mediaContent: some View {
		switch displayMode {
		case .introStatic:
			AsciiMediaView(catalogVideoNamed: VisionDisplayMode.introPlaceholderCatalogName)
				.asciiScaleMode(.fit)
		case .scene(let image), .recalled(_, let image):
			AsciiMediaView(image: image.cgImage)
				.asciiScaleMode(.fit)
		}
	}
}

private struct VisionLoadingOverlay: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 6) {
				Text(String(localized: "nan_vision_loading_title"))
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
				TerminalGlyphLoader(
					style: .blocks,
					textStyle: .caption2,
					weight: .bold,
					color: .terminalWarning
				)
			}
			.foregroundStyle(Color.terminalWarning)

			Text(String(localized: "nan_vision_loading_ram"))
				.font(.monocraft(relativeTo: .caption2))
				.foregroundStyle(Color.accent.opacity(0.72))
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 7)
		.background(Color.background.opacity(0.82))
		.drawBorder(nil, color: .terminalWarning.opacity(0.75), lineWidth: 1)
		.accessibilityHidden(true)
	}
}

struct CollapsedVisionBar: View {
	/// Whole-number percent while a scene is rendering. `nil` is the idle collapsed bar.
	var generationPercent: Int?
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			barLabel(
				title: generationPercent == nil
					? String(localized: "nan_vision_collapsed_title")
					: String(localized: "nan_vision_loading_title"),
				trailing: trailingText
			)
		}
		.buttonStyle(.plain)
		.foregroundStyle(generationPercent == nil ? Color.terminalMutedText : Color.terminalWarning)
		.fixedSize(horizontal: false, vertical: true)
		.drawBorder(
			nil,
			color: generationPercent == nil
				? Color.terminalMutedText.opacity(0.7)
				: Color.terminalWarning.opacity(0.75),
			lineWidth: 1
		)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityLabel)
		.accessibilityHint(
			generationPercent == nil ? "" : String(localized: "nan_vision_collapsed_a11y")
		)
	}

	private var accessibilityLabel: String {
		if let generationPercent {
			return String(format: String(localized: "nan_vision_collapsed_generating_a11y"), generationPercent)
		}
		return String(localized: "nan_vision_collapsed_a11y")
	}

	private var trailingText: String {
		guard let generationPercent else { return "OPEN" }
		return "\(percentText(generationPercent))  OPEN"
	}

	private func barLabel(title: String, trailing: String) -> some View {
		HStack {
			Text(title)
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
			Spacer()
			Text(trailing)
				.font(.monocraft(relativeTo: .caption2, weight: .semibold))
				.frame(minWidth: 44, alignment: .trailing)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 10)
		.frame(maxWidth: .infinity)
	}

	private func percentText(_ percent: Int) -> String {
		String(format: String(localized: "nan_vision_collapsed_progress"), percent)
	}
}

/// The open vision frame while a scene is rendering: a character ring with a turning arm, plus the status line.
private struct AsciiVisionSpinner: View {
	var percent: Int?

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var frame = 0

	var body: some View {
		Color.clear
			.aspectRatio(SceneFrame.widthOverHeight, contentMode: .fit)
			.frame(maxWidth: .infinity)
			.overlay {
				VStack(spacing: 10) {
					Text(picture)
						.font(.monocraft(relativeTo: .caption2))
						.foregroundStyle(Color.terminalWarning)
						.multilineTextAlignment(.center)
						.accessibilityHidden(true)
					Text(message)
						.font(.monocraft(relativeTo: .caption, weight: .semibold))
						.foregroundStyle(Color.terminalWarning)
						.multilineTextAlignment(.center)
				}
				.padding(12)
			}
			.accessibilityHidden(true)
			.task(id: reduceMotion) {
				await spin()
			}
	}

	private var picture: String {
		AsciiVisionSpinnerArt.lines(for: reduceMotion ? 0 : frame).joined(separator: "\n")
	}

	private var message: String {
		let title = String(localized: "nan_vision_loading_title")
		guard let percent else { return title }
		return "\(title)  \(String(format: String(localized: "nan_vision_collapsed_progress"), percent))"
	}

	private func spin() async {
		frame = 0
		guard !reduceMotion else { return }
		while !Task.isCancelled {
			try? await Task.sleep(for: TerminalMotion.loaderInterval)
			guard !Task.isCancelled else { return }
			frame = (frame + 1) % AsciiVisionSpinnerArt.frameCount
		}
	}
}

/// Monospace ring. The arm starts at 12 o'clock and steps clockwise.
enum AsciiVisionSpinnerArt {
	static let columns = 17
	static let rows = 9
	static let frameCount = 8

	static func lines(for phase: Int) -> [String] {
		let centerX = Double(columns - 1) / 2
		let centerY = Double(rows - 1) / 2
		let head = -.pi / 2 + (Double(phase.modulo(frameCount)) / Double(frameCount)) * (2 * .pi)
		return (0..<rows).map { row in
			String((0..<columns).map { column in
				glyph(column: column, row: row, centerX: centerX, centerY: centerY, head: head)
			})
		}
	}

	/// Character cells are taller than they are wide, so horizontal distance is scaled down.
	private static func glyph(column: Int, row: Int, centerX: Double, centerY: Double, head: Double) -> Character {
		let dx = (Double(column) - centerX) * 0.57
		let dy = Double(row) - centerY
		let radius = hypot(dx, dy)
		if radius < 0.45 { return "@" }

		var delta = atan2(dy, dx) - head
		while delta > .pi { delta -= 2 * .pi }
		while delta < -.pi { delta += 2 * .pi }
		let ahead = abs(delta)

		if radius <= 3.15, ahead < 0.38 { return "@" }
		if radius <= 3.15, ahead < 0.8 { return "▓" }
		if abs(radius - 3.35) < 0.55 {
			if ahead < 0.55 { return "▓" }
			if ahead < 1.15 { return "▒" }
			if ahead < 2 { return "░" }
			return "."
		}
		return " "
	}
}

private extension Int {
	func modulo(_ divisor: Int) -> Int {
		guard divisor > 0 else { return 0 }
		let remainder = self % divisor
		return remainder >= 0 ? remainder : remainder + divisor
	}
}

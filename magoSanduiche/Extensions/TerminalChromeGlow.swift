//
//  TerminalChromeGlow.swift
//  magoSanduiche
//
//  CRT-style phosphor bloom via stacked shadows; `progress` drives CRT border reveals.
//

import SwiftUI

enum TerminalGlowPreset {
	/// Bordered panels and primary chrome (`drawBorder`).
	case chrome
	/// Borderless taps (`TerminalSubtleButtonStyle`) — lower contrast than chrome.
	case subtle
}

extension View {
	/// Multi-layer shadow read as terminal phosphor. Opacity scales with `progress` (0...1).
	@ViewBuilder
	func terminalChromeGlow(
		color: Color,
		progress: CGFloat = 1,
		preset: TerminalGlowPreset = .chrome
	) -> some View {
		let p = Double(max(0, min(1, progress)))
		switch preset {
		case .chrome:
			self
				.shadow(color: color.opacity(0.26 * p), radius: 4, x: 0, y: 0)
				.shadow(color: color.opacity(0.20 * p), radius: 10, x: 0, y: 0)
				.shadow(color: color.opacity(0.11 * p), radius: 22, x: 0, y: 0)
		case .subtle:
			self
				.shadow(color: color.opacity(0.10 * p), radius: 6, x: 0, y: 0)
		}
	}
}

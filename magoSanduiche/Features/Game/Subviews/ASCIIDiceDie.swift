//
//  ASCIIDiceDie.swift
//  magoSanduiche
//

import SwiftUI

struct ASCIIDiceDie: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let value: Int
	let revealStage: DiceRevealStage
	let foregroundColor: Color
	let borderColor: Color

	var body: some View {
		Text(dieArt)
			.font(.monocraft(relativeTo: .caption2, weight: .bold))
			.foregroundStyle(foregroundColor)
			.lineSpacing(1)
			.multilineTextAlignment(.leading)
			.monospacedDigit()
			.frame(width: 132, height: 104, alignment: .center)
			.background(Color.terminalActiveSurface)
			.drawBorder(
				String(localized: "nan_dice_panel_title"),
				color: borderColor,
				lineWidth: 2,
				glowPreset: .subtle
			)
			.rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
			.rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
			.scaleEffect(scale)
			.opacity(opacity)
			.animation(rotationAnimation, value: value)
			.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.quickPressAnimation), value: revealStage)
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(String(localized: "nan_a11y_action_roll_d20"))
			.accessibilityValue("\(value)")
	}

	private var dieArt: String {
		let valueText = value < 10 ? " \(value)" : "\(value)"

		switch revealStage {
		case .scrambling:
			return """
				 _______
				/\\ \(valueText)  /\\
			   /::\\___/::\\
			   \\::/###\\::/
			    \\/_____\\/
			"""
		case .fadingOut, .suspense:
			return """
				 _______
				/\\     /\\
			   /::\\___/::\\
			   \\::/   \\::/
			    \\/_____\\/
			"""
		case .idle, .bamReveal:
			return """
				 _______
				/\\     /\\
			   /::\\ \(valueText) /::\\
			   \\::/___\\::/
			    \\/_____\\/
			"""
		}
	}

	private var opacity: Double {
		switch revealStage {
		case .fadingOut, .suspense:
			return 0
		case .idle, .scrambling, .bamReveal:
			return 1
		}
	}

	private var scale: CGFloat {
		guard !reduceMotion else {
			return revealStage == .scrambling ? 1.02 : 1
		}

		switch revealStage {
		case .scrambling:
			return 1.05
		case .fadingOut:
			return 1.04
		case .suspense:
			return 0.94
		case .bamReveal:
			return 1.02
		case .idle:
			return 1
		}
	}

	private var rotationX: Double {
		guard !reduceMotion else { return 0 }

		switch revealStage {
		case .scrambling:
			return value.isMultiple(of: 2) ? 18 : -18
		case .fadingOut:
			return 12
		case .suspense:
			return 0
		case .bamReveal:
			return -8
		case .idle:
			return -5
		}
	}

	private var rotationY: Double {
		guard !reduceMotion else { return 0 }

		switch revealStage {
		case .scrambling:
			return value.isMultiple(of: 3) ? -26 : 26
		case .fadingOut:
			return 20
		case .suspense:
			return 0
		case .bamReveal:
			return 8
		case .idle:
			return 6
		}
	}

	private var rotationAnimation: Animation? {
		guard !reduceMotion else { return nil }

		switch revealStage {
		case .scrambling:
			return .easeInOut(duration: 0.08)
		case .fadingOut, .suspense, .bamReveal, .idle:
			return TerminalMotion.quickPressAnimation
		}
	}
}

#Preview {
	VStack(spacing: 24) {
		ASCIIDiceDie(
			value: 17,
			revealStage: .scrambling,
			foregroundColor: .terminalWarning,
			borderColor: .terminalWarning
		)
		ASCIIDiceDie(
			value: 20,
			revealStage: .idle,
			foregroundColor: .accent,
			borderColor: .accent
		)
	}
	.padding()
	.background(Color.terminalGrid)
}

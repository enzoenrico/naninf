//
//  DiceRevealStage.swift
//  magoSanduiche
//

import Foundation

enum DiceRollRevealTiming {
	static let scrambleTicks = 12
	static let scrambleSlowMillis = 92
	static let scrambleFastMillis = 36

	/// How long the die face fades to black after the scramble settles (pairs with `TerminalMotion.diceFadeAnimation`).
	static let fadeOutMillis = 620
	static let fadeOutMillisReduceMotion = 240

	static let suspenseMillis = 1000
	static let suspenseMillisReduceMotion = 280

	static let bamRevealMillis = 240
	static let bamRevealMillisReduceMotion = 90

	static func fadeOutSeconds(reduceMotion: Bool) -> Double {
		Double(reduceMotion ? fadeOutMillisReduceMotion : fadeOutMillis) / 1000
	}

	static func suspenseSeconds(reduceMotion: Bool) -> Double {
		Double(reduceMotion ? suspenseMillisReduceMotion : suspenseMillis) / 1000
	}

	static func bamRevealSeconds(reduceMotion: Bool) -> Double {
		Double(reduceMotion ? bamRevealMillisReduceMotion : bamRevealMillis) / 1000
	}

	/// Delay after each random tick during `.scrambling`; steps accelerate (ease-in curve on progress).
	static func scrambleSleepMillis(step: Int) -> UInt64 {
		guard scrambleTicks >= 2 else {
			return UInt64(scrambleFastMillis)
		}
		let step = Swift.max(0, Swift.min(step, scrambleTicks - 1))
		let total = scrambleTicks - 1
		let t = Double(step) / Double(total)
		let easedIn = t * t
		let span = Double(scrambleSlowMillis - scrambleFastMillis)
		let ms = Double(scrambleSlowMillis) - span * easedIn
		return UInt64(ms.rounded())
	}
}

/// Phases inside `rollDice`: scramble → fade out → hidden suspense → bam reveal.
enum DiceRevealStage: Equatable {
	case idle
	case scrambling
	case fadingOut
	/// Face is invisible; `diceValue` already equals the final roll.
	case suspense
	case bamReveal
}

enum DiceOutcomeTier: Equatable {
	case low
	case mid
	case high

	init(roll: Int) {
		switch roll {
		case 1...6:
			self = .low
		case 7...14:
			self = .mid
		default:
			self = .high
		}
	}

	var analyticsName: String {
		switch self {
		case .low: "low"
		case .mid: "mid"
		case .high: "high"
		}
	}
}

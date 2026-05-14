//
//  DiceRevealStage.swift
//  magoSanduiche
//

import Foundation

enum DiceRollRevealTiming {
	static let tickMillis = 55
	/// How long the die face fades while values keep ticking (pairs with `DicePromptView` ease-out).
	static let fadeOutMillis = 620
	static let fadeOutMillisReduceMotion = 240

	static func fadeOutSeconds(reduceMotion: Bool) -> Double {
		Double(reduceMotion ? fadeOutMillisReduceMotion : fadeOutMillis) / 1000
	}
}

/// Phases inside `rollDice` after the scramble: fade out → hidden suspense → bam reveal.
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
}

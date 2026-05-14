//
//  TerminalHaptics.swift
//  magoSanduiche
//

import Foundation

#if os(iOS)
	import UIKit
#endif

enum TerminalHaptics {
	/// One medium “land”, then tier-specific follow-through after a breather (~50ms).
	static func playDiceReveal(roll: Int) {
		#if os(iOS)
			let tier = DiceOutcomeTier(roll: roll)
			let landing = UIImpactFeedbackGenerator(style: .medium)
			landing.prepare()
			landing.impactOccurred(intensity: 1.0)
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
				switch tier {
				case .low:
					let rigid = UIImpactFeedbackGenerator(style: .rigid)
					rigid.prepare()
					rigid.impactOccurred(intensity: 1.0)
				case .mid:
					let sel = UISelectionFeedbackGenerator()
					sel.prepare()
					sel.selectionChanged()
				case .high:
					let notify = UINotificationFeedbackGenerator()
					notify.prepare()
					notify.notificationOccurred(.success)
				}
			}
		#endif
	}
}

//
//  CreditCatalog.swift
//  magoSanduiche
//

import Foundation

/// Player-facing credit costs and RevenueCat product / entitlement IDs.
/// Aligned to live RC project `projcb74c4bd` (NanInf) — see docs/revenuecat-setup.md.
enum CreditCatalog {
	static let starterGrantCredits = 20
	static let monthlyScribeCredits = 120

	static let dmTurnCost = 1
	static let sceneImageCost = 3

	enum Entitlement {
		/// Monthly Scribe subscription (only entitlement in the live NanInf RC project).
		static let scribe = "scribe"
	}

	enum ProductID {
		static let starter40 = "com.kyou.naninf.credits.starter_40"
		static let plus100 = "com.kyou.naninf.credits.plus_100"
		static let vault250 = "com.kyou.naninf.credits.vault_250"
		static let scribeMonthly = "com.kyou.naninf.sub.scribe_monthly"

		static let consumables: [String] = [starter40, plus100, vault250]
		static let all: [String] = consumables + [scribeMonthly]
	}

	enum OfferingID {
		static let `default` = "default"
	}

	static func credits(forProductID productID: String) -> Int? {
		switch productID {
		case ProductID.starter40:
			return 40
		case ProductID.plus100:
			return 100
		case ProductID.vault250:
			return 250
		case ProductID.scribeMonthly:
			return monthlyScribeCredits
		default:
			return nil
		}
	}

	static func cost(for spend: CreditSpendKind) -> Int {
		switch spend {
		case .dmTurn:
			dmTurnCost
		case .sceneImage:
			sceneImageCost
		}
	}
}

enum CreditSpendKind: String, Codable, Sendable {
	case dmTurn = "dm_turn"
	case sceneImage = "scene_image"
}

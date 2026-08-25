//
//  CreditCatalog.swift
//  magoSanduiche
//

import Foundation

/// Player-facing credit costs and RevenueCat product / entitlement IDs.
/// Keep these in sync with App Store Connect + RevenueCat dashboard (see docs/revenuecat-setup.md).
enum CreditCatalog {
	static let starterGrantCredits = 20
	static let monthlyStipendCredits = 120

	static let dmTurnCost = 1
	static let sceneImageCost = 3

	enum Entitlement {
		/// Active paid credit access (packs attach as consumables; used for dashboard grouping).
		static let credits = "credits"
		/// Monthly stipend subscription entitlement.
		static let stipend = "stipend"
	}

	enum ProductID {
		static let starter40 = "com.kyou.naninf.credits.starter_40"
		static let plus100 = "com.kyou.naninf.credits.plus_100"
		static let vault250 = "com.kyou.naninf.credits.vault_250"
		static let stipendMonthly = "com.kyou.naninf.sub.stipend_monthly"

		static let consumables: [String] = [starter40, plus100, vault250]
		static let all: [String] = consumables + [stipendMonthly]
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
		case ProductID.stipendMonthly:
			return monthlyStipendCredits
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

//
//  SandwichOracle.swift
//  magoSanduiche
//

import Foundation

/// Random terminal-flavored lines for the home hero tagline easter egg.
enum SandwichOracle {
	private static let localizationKeys = [
		"nan_oracle_01",
		"nan_oracle_02",
		"nan_oracle_03",
		"nan_oracle_04",
		"nan_oracle_05",
		"nan_oracle_06",
		"nan_oracle_07",
		"nan_oracle_08",
	]

	static var defaultTagline: String {
		String(localized: "nan_home_tagline")
	}

	static func randomLine(excluding excluded: String? = nil) -> String {
		let pool = localizationKeys
			.map { String(localized: String.LocalizationValue($0)) }
			.filter { line in
				guard let excluded else { return true }
				return line != excluded
			}
		return pool.randomElement() ?? defaultTagline
	}
}

//
//  Icons.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

import SwiftUI

enum Icons: String {
	case dice
	case bread
	case cards
	case ink
	case search

	var rawValue: String {
		switch self {
		case .dice:
			"Dice"
		case .bread:
			"Bread"
		case .cards:
			"Cards"
		case .ink:
			"Ink"
		case .search:
			"search"
		}
	}

	init?(rawValue: ImageResource) {
		return nil
	}

}

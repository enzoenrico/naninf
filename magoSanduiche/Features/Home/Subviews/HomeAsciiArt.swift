//
//  HomeAsciiArt.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import Foundation

enum HomeAsciiArt {
	static let crest: String = """
	      .--^^^^--.
	     /  /\\__/\\  \\
	    |  ( o.o )  |
	     \\  \\/__\\/  /
	      `--.__.--`
	   ___[========]___
	  /   |  MAGO  |   \\
	 |  ~~|SANDUICHE|~~ |
	  \\___|________|___/
	     ////////////
	"""

	static var crestAccessibilityLabel: String {
		String(localized: "nan_home_crest_a11y")
	}
}

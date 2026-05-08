//
//  Spacing.swift
//  magoSanduiche
//
//  Spacing scale documented in DESIGN.md (`spacing:` block) exposed to Swift
//  so call sites can reference named tokens instead of raw numbers. The
//  numbers here are the source of truth — keep them in sync with the YAML.
//

import CoreGraphics

enum Spacing {
	static let xs: CGFloat = 7
	static let sm: CGFloat = 8
	static let md: CGFloat = 10
	static let lg: CGFloat = 12
	static let xl: CGFloat = 14
	static let layoutTop: CGFloat = 16
	static let layoutLeading: CGFloat = 20
	static let layoutBottom: CGFloat = 24
	static let layoutTrailing: CGFloat = 20
}

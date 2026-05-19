//
//  SandwichOracleTests.swift
//  magoSanduicheTests
//

import Testing
@testable import magoSanduiche

struct SandwichOracleTests {
	@Test func randomLineDiffersFromExcluded() {
		let excluded = SandwichOracle.defaultTagline
		for _ in 0..<24 {
			let line = SandwichOracle.randomLine(excluding: excluded)
			#expect(line != excluded)
		}
	}
}

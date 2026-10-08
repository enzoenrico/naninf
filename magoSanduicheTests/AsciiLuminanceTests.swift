//
//  AsciiLuminanceTests.swift
//  magoSanduicheTests
//

import Testing
@testable import magoSanduiche

struct AsciiLuminanceTests {
	@Test func aNarrowBandSpreadsAcrossTheRamp() {
		let pixels = [UInt8](repeating: 40, count: 50) + [UInt8](repeating: 80, count: 50)
		let stretched = AsciiLuminance.stretched(pixels)

		#expect(stretched.filter { $0 == 0 }.count == 50)
		#expect(stretched.filter { $0 == 255 }.count == 50)
	}

	@Test func aFlatFrameStaysFlat() {
		let pixels = [UInt8](repeating: 40, count: 40)
		#expect(AsciiLuminance.stretched(pixels) == pixels)
	}

	@Test func aFullRangeFrameStaysInRange() {
		let pixels: [UInt8] = [0, 64, 128, 192, 255, 0, 255, 128]
		let stretched = AsciiLuminance.stretched(pixels)
		#expect(stretched.allSatisfy { $0 >= 0 })
		#expect(stretched.min() == 0)
		#expect(stretched.max() == 255)
	}
}

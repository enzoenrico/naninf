//
//  DungeonMasterErrorTests.swift
//  magoSanduicheTests
//

import Foundation
import FoundationModels
import Testing
@testable import magoSanduiche

struct DungeonMasterErrorTests {
	@Test func everyFailureHasATerminalMessage() {
		let all: [DungeonMasterError] = [
			.unavailable(.deviceNotEligible),
			.unavailable(.systemNotReady),
			.quotaReached(resetDate: nil),
			.quotaReached(resetDate: Date(timeIntervalSince1970: 1_700_000_000)),
			.unreachable,
			.refused,
			.cancelled,
			.failed("x"),
		]
		#expect(all.allSatisfy { !$0.terminalMessage.isEmpty })
	}

	@Test func privateCloudAccessMapsAvailability() {
		#expect(PrivateCloudAccess(availability: .available) == .granted)
		#expect(
			PrivateCloudAccess(availability: .unavailable(.deviceNotEligible))
				== .denied(.deviceNotEligible)
		)
		#expect(
			PrivateCloudAccess(availability: .unavailable(.systemNotReady))
				== .denied(.systemNotReady)
		)
	}

	@Test func analyticsKindsStayClosed() {
		#expect(DungeonMasterError.unavailable(.deviceNotEligible).analyticsKind == "unavailable")
		#expect(DungeonMasterError.quotaReached(resetDate: nil).analyticsKind == "quota_reached")
		#expect(DungeonMasterError.unreachable.analyticsKind == "unreachable")
		#expect(DungeonMasterError.refused.analyticsKind == "refused")
		#expect(DungeonMasterError.cancelled.analyticsKind == "cancelled")
		#expect(DungeonMasterError.failed("x").analyticsKind == "failed")
	}
}

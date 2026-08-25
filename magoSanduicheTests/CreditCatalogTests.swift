import Testing
@testable import magoSanduiche

struct CreditCatalogTests {
	@Test func dmTurnAndImageCostsMatchADRSketch() {
		#expect(CreditCatalog.cost(for: .dmTurn) == 1)
		#expect(CreditCatalog.cost(for: .sceneImage) == 3)
		#expect(CreditCatalog.starterGrantCredits == 20)
		#expect(CreditCatalog.monthlyStipendCredits == 120)
	}

	@Test func productCreditMapIsCompleteForStorefront() {
		#expect(CreditCatalog.credits(forProductID: CreditCatalog.ProductID.starter40) == 40)
		#expect(CreditCatalog.credits(forProductID: CreditCatalog.ProductID.plus100) == 100)
		#expect(CreditCatalog.credits(forProductID: CreditCatalog.ProductID.vault250) == 250)
		#expect(CreditCatalog.credits(forProductID: CreditCatalog.ProductID.stipendMonthly) == 120)
		#expect(CreditCatalog.credits(forProductID: "unknown") == nil)
	}

	@Test func packageKindsRoundTripProductIDs() {
		for kind in NanInfPackageKind.allCases {
			#expect(NanInfPackageKind.kind(forProductID: kind.productID) == kind)
		}
	}
}

import Foundation
import Testing
@testable import magoSanduiche

struct AuthTests {
	@Test func configurationLoadsWithOnlySupabaseValues() throws {
		let configuration = try AppAuthConfiguration.load(infoDictionary: [
			"SUPABASE_URL": "https://example.supabase.co",
			"SUPABASE_PUBLISHABLE_KEY": "pk",
		])
		#expect(configuration.supabaseURL.absoluteString == "https://example.supabase.co")
		#expect(configuration.supabasePublishableKey == "pk")
	}

	@Test func configurationReportsMissingValue() {
		expectMissingValue("SUPABASE_URL", in: [
			"SUPABASE_PUBLISHABLE_KEY": "pk",
		])
		expectMissingValue("SUPABASE_PUBLISHABLE_KEY", in: [
			"SUPABASE_URL": "https://example.supabase.co",
		])
		expectMissingValue("SUPABASE_URL", in: [
			"SUPABASE_URL": "  ",
			"SUPABASE_PUBLISHABLE_KEY": "pk",
		])
		expectMissingValue("SUPABASE_URL", in: [
			"SUPABASE_URL": "$(SUPABASE_URL)",
			"SUPABASE_PUBLISHABLE_KEY": "pk",
		])
	}

	@Test @MainActor func legacyGoogleSnapshotStillDecodes() throws {
		let json = #"{"userID":"user-1","email":"a@b.c","provider":"google","displayName":"Mago","signedInAt":721692800}"#
		let snapshot = try JSONDecoder().decode(AuthLoginSnapshot.self, from: Data(json.utf8))
		let signedInAt = try JSONDecoder().decode(Date.self, from: Data("721692800".utf8))

		#expect(snapshot.provider == .google)
		#expect(snapshot.userID == "user-1")
		#expect(snapshot.email == "a@b.c")
		#expect(snapshot.displayName == "Mago")
		#expect(snapshot.signedInAt == signedInAt)
	}

	private func expectMissingValue(_ key: String, in infoDictionary: [String: Any]) {
		var reported: String?
		do {
			_ = try AppAuthConfiguration.load(infoDictionary: infoDictionary)
		} catch AppAuthConfigurationError.missingValue(let name) {
			reported = name
		} catch {
			reported = nil
		}
		#expect(reported == key)
	}
}

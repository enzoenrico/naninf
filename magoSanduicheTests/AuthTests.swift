import AuthenticationServices
import Foundation
import Testing
@testable import magoSanduiche

struct AuthTests {
	@Test func legacyGoogleSnapshotStillDecodes() throws {
		let json = #"{"userID":"user-1","email":"a@b.c","provider":"google","displayName":"Mago","signedInAt":721692800}"#
		let snapshot = try JSONDecoder().decode(AuthLoginSnapshot.self, from: Data(json.utf8))
		let signedInAt = try JSONDecoder().decode(Date.self, from: Data("721692800".utf8))

		#expect(snapshot.provider == .google)
		#expect(snapshot.userID == "user-1")
		#expect(snapshot.email == "a@b.c")
		#expect(snapshot.displayName == "Mago")
		#expect(snapshot.signedInAt == signedInAt)
	}

	@Test func snapshotRoundTripsThroughDefaults() throws {
		let suiteName = "auth-tests-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let snapshot = AuthLoginSnapshot(
			userID: "apple-user",
			email: "wizard@mago.test",
			provider: .apple,
			displayName: "Sandwich Wizard",
			signedInAt: Date(timeIntervalSince1970: 1_700_000_000)
		)
		let store = AuthLoginSnapshotStore(defaults: defaults)
		store.save(snapshot)

		#expect(store.load() == snapshot)
		store.clear()
		#expect(store.load() == nil)
	}

	@Test @MainActor func storedSnapshotSignsInWithoutRemoteSession() async {
		let suiteName = "auth-session-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let snapshot = AuthLoginSnapshot(
			userID: "user-1",
			email: "a@b.c",
			provider: .google,
			displayName: "Mago",
			signedInAt: Date(timeIntervalSince1970: 721_692_800)
		)
		AuthLoginSnapshotStore(defaults: defaults).save(snapshot)

		let session = AuthSessionStore(defaults: defaults)
		await session.start()

		#expect(session.isAuthenticated)
		#expect(session.loginSnapshot == snapshot)
		#expect(session.isLoadingSession == false)

		await session.signOut()

		#expect(session.isAuthenticated == false)
		#expect(session.loginSnapshot == nil)
		#expect(AuthLoginSnapshotStore(defaults: defaults).load() == nil)
	}

	@Test @MainActor func appleSnapshotStaysSignedInWhenCredentialIsNotFound() async {
		let suiteName = "auth-apple-not-found-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let snapshot = AuthLoginSnapshot(
			userID: "apple-user",
			email: "wizard@mago.test",
			provider: .apple,
			displayName: "Sandwich Wizard",
			signedInAt: Date(timeIntervalSince1970: 1_700_000_000)
		)
		AuthLoginSnapshotStore(defaults: defaults).save(snapshot)

		let session = AuthSessionStore(defaults: defaults) { _ in .notFound }
		await session.start()

		#expect(session.isAuthenticated)
		#expect(session.loginSnapshot == snapshot)
		#expect(defaults.bool(forKey: "hasCompletedOnboarding") == false)
	}

	@Test @MainActor func revokedAppleCredentialClearsStoredSession() async {
		let suiteName = "auth-apple-revoked-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let snapshot = AuthLoginSnapshot(
			userID: "apple-user",
			email: "wizard@mago.test",
			provider: .apple,
			displayName: "Sandwich Wizard",
			signedInAt: Date(timeIntervalSince1970: 1_700_000_000)
		)
		AuthLoginSnapshotStore(defaults: defaults).save(snapshot)

		let session = AuthSessionStore(defaults: defaults) { _ in .revoked }
		await session.start()

		#expect(session.isAuthenticated == false)
		#expect(session.loginSnapshot == nil)
		#expect(AuthLoginSnapshotStore(defaults: defaults).load() == nil)
	}

	@Test @MainActor func onlyRevokedAppleCredentialClearsTheSession() {
		#expect(AuthSessionStore.shouldClearStoredSession(for: .revoked))
		#expect(AuthSessionStore.shouldClearStoredSession(for: .notFound) == false)
		#expect(AuthSessionStore.shouldClearStoredSession(for: .authorized) == false)
		#expect(AuthSessionStore.shouldClearStoredSession(for: .transferred) == false)
	}
}

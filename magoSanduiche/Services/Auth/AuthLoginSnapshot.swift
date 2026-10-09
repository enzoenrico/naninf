//
//  AuthLoginSnapshot.swift
//  magoSanduiche
//

import Foundation

enum PlayerAuthProvider: String, Codable {
	case apple
	case google
	case unknown
}

struct AuthLoginSnapshot: Codable, Equatable {
	let userID: String
	let email: String?
	let provider: PlayerAuthProvider
	let displayName: String?
	let signedInAt: Date

	init(
		userID: String,
		email: String?,
		provider: PlayerAuthProvider,
		displayName: String?,
		signedInAt: Date = Date()
	) {
		self.userID = userID
		self.email = email
		self.provider = provider
		self.displayName = displayName
		self.signedInAt = signedInAt
	}
}

struct AuthLoginSnapshotStore {
	private enum StorageKey {
		static let loginSnapshot = "authLoginSnapshot"
		static let hasCompletedOnboarding = "hasCompletedOnboarding"
		static let hasUnlockedFullGame = "hasUnlockedFullGame"
	}

	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func load() -> AuthLoginSnapshot? {
		guard let data = defaults.data(forKey: StorageKey.loginSnapshot) else { return nil }
		return try? JSONDecoder().decode(AuthLoginSnapshot.self, from: data)
	}

	func save(_ snapshot: AuthLoginSnapshot) {
		guard let data = try? JSONEncoder().encode(snapshot) else { return }
		defaults.set(data, forKey: StorageKey.loginSnapshot)
	}

	/// Apple sign-in is the end of onboarding. Persist the gate here so the next
	/// launch opens the player home even if the sign-in view is still on screen.
	func markOnboardingComplete() {
		defaults.set(true, forKey: StorageKey.hasCompletedOnboarding)
		defaults.set(true, forKey: StorageKey.hasUnlockedFullGame)
	}

	func clear() {
		defaults.removeObject(forKey: StorageKey.loginSnapshot)
	}
}

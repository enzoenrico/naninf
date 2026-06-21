//
//  AuthLoginSnapshot.swift
//  magoSanduiche
//

import Foundation
import Supabase

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

	init(session: Session, provider overrideProvider: PlayerAuthProvider? = nil, signedInAt: Date = Date()) {
		let user = session.user
		userID = user.id.uuidString
		email = user.email
		provider = overrideProvider ?? PlayerAuthProvider(rawValue: user.identities?.last?.provider ?? "") ?? .unknown
		displayName = user.userMetadata.stringValue(for: "full_name")
			?? user.userMetadata.stringValue(for: "name")
		self.signedInAt = signedInAt
	}

	#if DEBUG
		/// Builds a snapshot without a Supabase `Session`, for UI-test injection only.
		init(
			uiTestUserID: String,
			email: String?,
			provider: PlayerAuthProvider,
			displayName: String?,
			signedInAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
		) {
			userID = uiTestUserID
			self.email = email
			self.provider = provider
			self.displayName = displayName
			self.signedInAt = signedInAt
		}
	#endif
}

struct AuthLoginSnapshotStore {
	private enum StorageKey {
		static let loginSnapshot = "authLoginSnapshot"
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

	func clear() {
		defaults.removeObject(forKey: StorageKey.loginSnapshot)
	}
}

private extension Dictionary where Key == String, Value == AnyJSON {
	func stringValue(for key: String) -> String? {
		guard let value = self[key] else { return nil }
		guard let data = try? JSONEncoder().encode(value) else { return nil }
		return try? JSONDecoder().decode(String.self, from: data)
	}
}

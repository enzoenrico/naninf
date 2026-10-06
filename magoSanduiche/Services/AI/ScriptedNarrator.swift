//
//  ScriptedNarrator.swift
//  magoSanduiche
//

#if DEBUG
	import Foundation

	final class ScriptedNarrator: DungeonNarrator {
		static let defaultsKey = "DungeonMaster.scriptedNarrator"

		static var isEnabledByDefaults: Bool {
			UserDefaults.standard.bool(forKey: defaultsKey)
		}

		private(set) var prompts: [String] = []
		private var drafts: [DungeonTurnDraft]
		private let failure: DungeonMasterError?
		private var lastDraft: DungeonTurnDraft?

		init(drafts: [DungeonTurnDraft]) {
			self.drafts = drafts
			self.failure = nil
		}

		init(failure: DungeonMasterError) {
			self.drafts = []
			self.failure = failure
		}

		static func demo() -> ScriptedNarrator {
			ScriptedNarrator(drafts: [])
		}

		func draft(
			for prompt: String,
			analyticsContext: AIAnalyticsContext?
		) async throws(DungeonMasterError) -> DungeonTurnDraft {
			_ = analyticsContext
			prompts.append(prompt)
			if let failure {
				throw failure
			}

			let draft: DungeonTurnDraft
			if drafts.isEmpty {
				draft = lastDraft ?? Self.echoDraft(for: prompt)
			} else {
				draft = drafts.removeFirst()
			}
			lastDraft = draft
			return draft
		}

		private static func echoDraft(for prompt: String) -> DungeonTurnDraft {
			let playerMessage = prompt
				.split(separator: "\n")
				.first { $0.hasPrefix("playerMessage: ") }
				.map { String($0.dropFirst("playerMessage: ".count)) }
			let narrative = playerMessage.map { "> \($0)" } ?? "> The dungeon waits."
			return DungeonTurnDraft(
				narrative: narrative,
				healthChange: 0,
				manaChange: 0,
				nextInput: .write,
				options: ["Look closer", "Step back", "Call out"],
				visualPrompt: ""
			)
		}
	}

	extension DungeonTurnDraft {
		static func fixture(
			narrative: String = "> Test",
			healthChange: Int = 0,
			manaChange: Int = 0,
			nextInput: NextInput = .write,
			options: [String] = ["A", "B", "C"],
			visualPrompt: String = ""
		) -> DungeonTurnDraft {
			DungeonTurnDraft(
				narrative: narrative,
				healthChange: healthChange,
				manaChange: manaChange,
				nextInput: nextInput,
				options: options,
				visualPrompt: visualPrompt
			)
		}
	}
#endif

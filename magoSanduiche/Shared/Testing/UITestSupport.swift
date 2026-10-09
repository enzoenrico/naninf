//
//  UITestSupport.swift
//  magoSanduiche
//
//  DEBUG-only harness that lets UI tests drive the app into a specific screen and
//  state deterministically, bypassing onboarding gating, sign-in, and the
//  remote game services. Activated by the launch argument:
//
//      -uiTestScenario <UITestScenario.rawValue>
//
//  NOTE: `ScreenshotTests` in the UI-test target keeps its own copy of the scenario
//  raw values (a test process cannot import the app module). Keep both lists in sync.
//

#if DEBUG

import Foundation
import SwiftData

#if canImport(UIKit)
	import UIKit
#endif

// MARK: - Scenario inputs

enum UITestAuthMode {
	case authenticated
	case unauthenticated
	case configMissing
	case error
	case loading
}

enum UITestRunSeed {
	case none
	case empty
	case populated
}

/// Snapshot of the deterministic `GameViewModel` + coordinator presentation state for a game screen.
struct UITestGameFixture {
	var phase: GameUIPhase = .ready
	var contextAction: GameAction = .write
	var health = 50
	var mana = 20
	var maxHealth = 50
	var maxMana = 30
	var terminalEntries: [TerminalEntry] = []
	var suggestedOptions: [String] = []
	var showsSuggestions = false
	var dicePromptVisible = false
	var diceValue = 20
	var diceRevealStage: DiceRevealStage = .idle
	var pendingDiceRoll: Int?
	var diceResultText = String(localized: "nan_dice_idle_cold")
	var contextualInputVisible = false
	var contextualInput = ""
	var imageCollapsed = true
	var invalidInputAttempts = 0
	var loading = false
	var showActionButton = true
	var hasCompletedInitialText = true
}

/// How a single scenario should configure the app before its screen is captured.
struct UITestPlan {
	var authMode: UITestAuthMode = .authenticated
	var onboardingCompleted = true
	var seedsProfileData = false
	var initialRoute: AppRoute?
	var onboardingStep: OnboardingStep?
	var runSeed: UITestRunSeed = .none
	var gameFixture: UITestGameFixture?
	var forcesBoot = false
}

// MARK: - Scenarios

enum UITestScenario: String, CaseIterable {
	// Startup
	case boot

	// Onboarding (one per step + an authenticated sign-in variant)
	case onboardingWelcome
	case onboardingGoal
	case onboardingPainPoints
	case onboardingSocialProof
	case onboardingSolution
	case onboardingPreferences
	case onboardingProcessing
	case onboardingDemo
	case onboardingSignIn
	case onboardingSignInBound

	// Auth gate
	case authReady
	case authConfigMissing
	case authError
	case authChecking

	// Hub
	case home
	case profile
	case about

	// Load run library
	case loadEmpty
	case loadPopulated

	// Game session states
	case gameReading
	case gameReady
	case gameComposing
	case gameSuggestions
	case gameAwaitingDM
	case gameRollingDice
	case gameDiceRevealed
	case gameResult
	case gameVisionExpanded
	case gameLowResources
	case gameInvalidInput

	var plan: UITestPlan {
		switch self {
		case .boot:
			return UITestPlan(authMode: .authenticated, onboardingCompleted: true, forcesBoot: true)

		case .onboardingWelcome:
			return onboardingPlan(.welcome)
		case .onboardingGoal:
			return onboardingPlan(.goal)
		case .onboardingPainPoints:
			return onboardingPlan(.painPoints)
		case .onboardingSocialProof:
			return onboardingPlan(.socialProof)
		case .onboardingSolution:
			return onboardingPlan(.solution)
		case .onboardingPreferences:
			return onboardingPlan(.preferences)
		case .onboardingProcessing:
			return onboardingPlan(.processing)
		case .onboardingDemo:
			return onboardingPlan(.demo)
		case .onboardingSignIn:
			return onboardingPlan(.signIn, auth: .unauthenticated)
		case .onboardingSignInBound:
			return onboardingPlan(.signIn, auth: .authenticated)

		case .authReady:
			return UITestPlan(authMode: .unauthenticated, onboardingCompleted: true)
		case .authConfigMissing:
			return UITestPlan(authMode: .configMissing, onboardingCompleted: true)
		case .authError:
			return UITestPlan(authMode: .error, onboardingCompleted: true)
		case .authChecking:
			return UITestPlan(authMode: .loading, onboardingCompleted: true)

		case .home:
			return UITestPlan(authMode: .authenticated, onboardingCompleted: true, seedsProfileData: true)
		case .profile:
			return UITestPlan(
				authMode: .authenticated,
				onboardingCompleted: true,
				seedsProfileData: true,
				initialRoute: .profile
			)
		case .about:
			return UITestPlan(authMode: .authenticated, onboardingCompleted: true, initialRoute: .about)

		case .loadEmpty:
			return UITestPlan(
				authMode: .authenticated,
				onboardingCompleted: true,
				initialRoute: .load,
				runSeed: .empty
			)
		case .loadPopulated:
			return UITestPlan(
				authMode: .authenticated,
				onboardingCompleted: true,
				initialRoute: .load,
				runSeed: .populated
			)

		case .gameReading:
			return gamePlan(Self.readingFixture)
		case .gameReady:
			return gamePlan(Self.readyFixture)
		case .gameComposing:
			return gamePlan(Self.composingFixture)
		case .gameSuggestions:
			return gamePlan(Self.suggestionsFixture)
		case .gameAwaitingDM:
			return gamePlan(Self.awaitingFixture)
		case .gameRollingDice:
			return gamePlan(Self.rollingFixture)
		case .gameDiceRevealed:
			return gamePlan(Self.diceRevealedFixture)
		case .gameResult:
			return gamePlan(Self.resultFixture)
		case .gameVisionExpanded:
			return gamePlan(Self.visionExpandedFixture)
		case .gameLowResources:
			return gamePlan(Self.lowResourcesFixture)
		case .gameInvalidInput:
			return gamePlan(Self.invalidInputFixture)
		}
	}

	private func onboardingPlan(_ step: OnboardingStep, auth: UITestAuthMode = .unauthenticated) -> UITestPlan {
		UITestPlan(authMode: auth, onboardingCompleted: false, onboardingStep: step)
	}

	private func gamePlan(_ fixture: UITestGameFixture) -> UITestPlan {
		UITestPlan(
			authMode: .authenticated,
			onboardingCompleted: true,
			initialRoute: .game,
			gameFixture: fixture
		)
	}
}

// MARK: - Game fixtures

extension UITestScenario {
	static var baseTranscript: [TerminalEntry] {
		[
			TerminalEntry(kind: .dungeonMaster, text: Introduction.intro),
			TerminalEntry(kind: .player, text: "I shoulder open the warped tavern door and step inside."),
			TerminalEntry(
				kind: .dungeonMaster,
				text: "The hinges shriek. Lantern light gutters across a hall of empty stools and a barkeep who has not blinked in a very long time."
			),
		]
	}

	static var sampleSuggestions: [String] {
		[
			"Approach the silent barkeep.",
			"Search the abandoned tables.",
			"Draw your wand and listen.",
		]
	}

	static var readingFixture: UITestGameFixture {
		var f = UITestGameFixture()
		f.phase = .reading
		f.terminalEntries = [TerminalEntry(kind: .dungeonMaster, text: Introduction.intro)]
		f.imageCollapsed = false
		f.hasCompletedInitialText = false
		f.showActionButton = false
		return f
	}

	static var readyFixture: UITestGameFixture {
		var f = UITestGameFixture()
		f.phase = .ready
		f.terminalEntries = baseTranscript
		f.suggestedOptions = sampleSuggestions
		return f
	}

	static var composingFixture: UITestGameFixture {
		var f = readyFixture
		f.phase = .composing
		f.contextualInputVisible = true
		f.contextualInput = "I raise my wand and whisper the unbinding cant."
		f.imageCollapsed = true
		return f
	}

	static var suggestionsFixture: UITestGameFixture {
		var f = readyFixture
		f.showsSuggestions = true
		return f
	}

	static var awaitingFixture: UITestGameFixture {
		var f = readyFixture
		f.phase = .awaitingDungeonMaster
		f.loading = true
		return f
	}

	static var rollingFixture: UITestGameFixture {
		var f = UITestGameFixture()
		f.phase = .rollingDice
		f.contextAction = .roll
		f.terminalEntries = baseTranscript
		f.dicePromptVisible = true
		f.imageCollapsed = true
		return f
	}

	static var diceRevealedFixture: UITestGameFixture {
		var f = UITestGameFixture()
		f.phase = .result
		f.contextAction = .roll
		f.terminalEntries = baseTranscript
		f.dicePromptVisible = true
		f.diceValue = 18
		f.diceRevealStage = .bamReveal
		f.pendingDiceRoll = 18
		f.diceResultText = "18 // the dice remember your name"
		f.imageCollapsed = true
		return f
	}

	static var resultFixture: UITestGameFixture {
		var f = UITestGameFixture()
		f.phase = .result
		f.terminalEntries = baseTranscript + [
			TerminalEntry(kind: .dice, text: "d20 -> 18 (mid)"),
			TerminalEntry(
				kind: .dungeonMaster,
				text: "The barkeep's jaw unhinges into a grin of broken teeth. 'Took you long enough, wizard.'"
			),
		]
		f.health = 44
		f.mana = 12
		return f
	}

	static var visionExpandedFixture: UITestGameFixture {
		var f = readyFixture
		f.imageCollapsed = false
		return f
	}

	static var lowResourcesFixture: UITestGameFixture {
		var f = readyFixture
		f.health = 6
		f.mana = 1
		f.phase = .ready
		return f
	}

	static var invalidInputFixture: UITestGameFixture {
		var f = readyFixture
		f.phase = .composing
		f.contextualInputVisible = true
		f.contextualInput = "?!?!"
		f.invalidInputAttempts = 2
		f.imageCollapsed = true
		return f
	}
}

// MARK: - Configuration entry point

enum UITestConfiguration {
	static let scenarioArgument = "-uiTestScenario"

	static let scenario: UITestScenario? = {
		let arguments = ProcessInfo.processInfo.arguments
		guard let index = arguments.firstIndex(of: scenarioArgument),
			arguments.indices.contains(index + 1)
		else {
			return nil
		}
		return UITestScenario(rawValue: arguments[index + 1])
	}()

	static var isActive: Bool { scenario != nil }

	static var plan: UITestPlan { scenario?.plan ?? UITestPlan() }

	static var authMode: UITestAuthMode { plan.authMode }

	static var initialRoute: AppRoute? { plan.initialRoute }

	static var onboardingStep: OnboardingStep? { plan.onboardingStep }

	static var gameFixture: UITestGameFixture? { plan.gameFixture }

	/// Boot animation is skipped unless a scenario explicitly wants it.
	static var skipsBoot: Bool { isActive && !plan.forcesBoot }

	static var onboardingResponses: OnboardingResponses { sampleOnboardingResponses }

	private static let sampleOnboardingResponses = OnboardingResponses(
		selectedGoalID: "magic_roleplay",
		selectedPainPointIDs: ["too_many_rules", "slow_setup"],
		selectedPreferenceIDs: ["heroic", "mysterious"]
	)

	/// Called from `magoSanduicheApp.init()` before any view reads `UserDefaults`.
	@MainActor
	static func applyLaunchSeedIfNeeded() {
		guard isActive else { return }

		#if canImport(UIKit)
			UIView.setAnimationsEnabled(false)
		#endif

		let defaults = UserDefaults.standard
		let plan = plan

		defaults.set(plan.onboardingCompleted, forKey: "hasCompletedOnboarding")
		defaults.set(plan.onboardingCompleted, forKey: "hasUnlockedFullGame")
		defaults.set(true, forKey: "hasSeenGameTips")

		if plan.seedsProfileData {
			if let data = try? JSONEncoder().encode(sampleOnboardingResponses) {
				defaults.set(data, forKey: "onboardingResponses")
			}
			defaults.set(Date(timeIntervalSince1970: 1_700_000_000).timeIntervalSince1970, forKey: "unlockDate")
			defaults.set(7, forKey: "runsStarted")
			defaults.set(3, forKey: "runsVictories")
			defaults.set(4, forKey: "runsDefeats")
			defaults.set(2, forKey: "bestStreak")
		} else {
			defaults.removeObject(forKey: "onboardingResponses")
			defaults.removeObject(forKey: "unlockDate")
			defaults.removeObject(forKey: "runsStarted")
			defaults.removeObject(forKey: "runsVictories")
			defaults.removeObject(forKey: "runsDefeats")
			defaults.removeObject(forKey: "bestStreak")
		}
	}

	/// In-memory SwiftData container seeded per scenario, or `nil` when not running a UI test.
	@MainActor
	static func makeModelContainerIfNeeded() -> ModelContainer? {
		guard isActive else { return nil }
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		guard let container = try? ModelContainer(
			for: Schema(GameRunPersistSchema.models),
			configurations: [configuration]
		) else {
			return nil
		}
		seedRuns(into: container.mainContext)
		return container
	}

	@MainActor
	private static func seedRuns(into context: ModelContext) {
		guard plan.runSeed == .populated else { return }

		let now = Date()
		let samples: [(title: String, health: Int, mana: Int, ageHours: Double)] = [
			("The Sealed Vault of Embers", 42, 18, 1),
			("Down the Sandwich Catacombs", 27, 9, 26),
			("The Barkeep Who Would Not Blink", 50, 30, 72),
		]

		for sample in samples {
			let createdAt = now.addingTimeInterval(-sample.ageHours * 3600 - 600)
			let updatedAt = now.addingTimeInterval(-sample.ageHours * 3600)
			let entries = [
				TerminalEntry(kind: .player, text: sample.title),
				TerminalEntry(kind: .dungeonMaster, text: Introduction.intro),
			]
			let live = GameRunSnapshotMapper.LiveState(
				terminalEntries: entries,
				suggestedOptions: [],
				health: sample.health,
				mana: sample.mana,
				maxHealth: 50,
				maxMana: 30,
				diceValue: 20,
				pendingDiceRoll: nil,
				diceRevealStage: .idle,
				diceResultText: String(localized: "nan_dice_idle_cold"),
				invalidInputAttempts: 0,
				contextualInput: "",
				contextAction: .write,
				uiPhase: .ready,
				suppressTerminalAnimations: true
			)
			guard let fields = try? GameRunSnapshotMapper.snapshotFields(from: live, createdAt: createdAt) else {
				continue
			}
			let run = GameRunSnapshotMapper.makeStoredGameRun(
				id: UUID(),
				createdAt: createdAt,
				updatedAt: updatedAt,
				fields: fields,
				analyticsSessionID: "uitest"
			)
			context.insert(run)
		}

		try? context.save()
	}
}

#endif

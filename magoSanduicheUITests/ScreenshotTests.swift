//
//  ScreenshotTests.swift
//  magoSanduicheUITests
//
//  Launches the app once per (language x scenario) and saves a screenshot as a
//  test attachment. Each scenario is driven by the DEBUG-only harness in the app
//  target (`UITestSupport.swift`) via the `-uiTestScenario` launch argument, so
//  gated screens (onboarding / auth) and remote-driven game states render
//  deterministically without network access.
//
//  Run on macOS:
//    xcodebuild test \
//      -scheme magoSanduiche \
//      -destination 'platform=iOS Simulator,name=iPhone 16' \
//      -only-testing:magoSanduicheUITests/ScreenshotTests
//
//  Screenshots land in the resulting .xcresult bundle (Xcode Report navigator,
//  or `xcrun xcresulttool export ...`).
//

import XCTest

final class ScreenshotTests: XCTestCase {
	/// Mirror of `UITestScenario.allCases.rawValue` in the app target.
	/// Keep this list in sync with `UITestScenario` in `UITestSupport.swift`.
	private static let scenarios: [String] = [
		"boot",

		"onboardingWelcome",
		"onboardingGoal",
		"onboardingPainPoints",
		"onboardingSocialProof",
		"onboardingSolution",
		"onboardingPreferences",
		"onboardingProcessing",
		"onboardingDemo",
		"onboardingSignIn",
		"onboardingSignInBound",

		"authReady",
		"authConfigMissing",
		"authError",
		"authChecking",

		"home",
		"profile",
		"about",

		"loadEmpty",
		"loadPopulated",

		"gameReading",
		"gameReady",
		"gameComposing",
		"gameSuggestions",
		"gameAwaitingDM",
		"gameRollingDice",
		"gameDiceRevealed",
		"gameResult",
		"gameVisionExpanded",
		"gameLowResources",
		"gameInvalidInput",
	]

	private static let scenarioArgument = "-uiTestScenario"

	/// Time to let the target screen settle before capturing.
	private static let renderDelay: TimeInterval = 1.2

	override func setUpWithError() throws {
		// Capture every scenario even if one launch misbehaves.
		continueAfterFailure = true
	}

	@MainActor
	func test_screenshots_en() throws {
		try captureAllScenarios(language: "en", locale: "en_US")
	}

	@MainActor
	func test_screenshots_ptBR() throws {
		try captureAllScenarios(language: "pt-BR", locale: "pt_BR")
	}

	@MainActor
	private func captureAllScenarios(language: String, locale: String) throws {
		for scenario in Self.scenarios {
			let app = XCUIApplication()
			app.launchArguments = [
				Self.scenarioArgument, scenario,
				"-AppleLanguages", "(\(language))",
				"-AppleLocale", locale,
			]
			app.launch()

			XCTAssertTrue(
				app.wait(for: .runningForeground, timeout: 10),
				"App did not reach foreground for \(language)/\(scenario)"
			)
			Thread.sleep(forTimeInterval: Self.renderDelay)

			let attachment = XCTAttachment(screenshot: app.screenshot())
			attachment.name = "\(language)__\(scenario)"
			attachment.lifetime = .keepAlways
			add(attachment)

			app.terminate()
		}
	}
}

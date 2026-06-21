//
//  OnboardingViewModel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import Foundation

@Observable
final class OnboardingViewModel {
	let demoActionTarget = 3
	private(set) var currentIndex = 0
	private(set) var completedDemoActions = 0
	var responses = OnboardingResponses()

	func persistResponsesOnUnlock(now: Date = Date()) {
		let defaults = UserDefaults.standard
		if let encoded = try? JSONEncoder().encode(responses) {
			defaults.set(encoded, forKey: "onboardingResponses")
		}
		// Only stamp the unlock date once.
		if defaults.object(forKey: "unlockDate") == nil {
			defaults.set(now.timeIntervalSince1970, forKey: "unlockDate")
		}
	}

	var primaryButtonTitle: String {
		switch currentStep {
		case .welcome:
			String(localized: "nan_onboarding_button_open_gate")
		case .goal, .painPoints, .preferences:
			String(localized: "nan_onboarding_button_continue")
		case .socialProof:
			String(localized: "nan_onboarding_button_show_how")
		case .solution:
			String(localized: "nan_onboarding_button_bind")
		case .processing:
			String(localized: "nan_onboarding_button_binding")
		case .demo:
			String(localized: "nan_onboarding_button_play_demo")
		case .signIn:
			String(localized: "nan_onboarding_button_enter_dungeon")
		}
	}

	var currentStep: OnboardingStep {
		OnboardingStep.allCases[currentIndex]
	}

	var isOnFinalPage: Bool {
		currentStep == .signIn
	}

	var progressText: String {
		String(
			format: String(localized: "nan_onboarding_progress_format"),
			locale: .current,
			arguments: [currentIndex + 1, OnboardingStep.allCases.count] as [CVarArg]
		)
	}

	var progress: Double {
		Double(currentIndex + 1) / Double(OnboardingStep.allCases.count)
	}

	var shouldShowPrimaryButton: Bool {
		currentStep != .demo
	}

	var demoProgressText: String {
		"\(min(completedDemoActions, demoActionTarget))/\(demoActionTarget)"
	}

	var canContinue: Bool {
		switch currentStep {
		case .goal:
			responses.selectedGoalID != nil
		case .painPoints:
			!responses.selectedPainPointIDs.isEmpty
		case .preferences:
			!responses.selectedPreferenceIDs.isEmpty
		case .processing:
			false
		case .demo:
			false
		case .welcome, .socialProof, .solution:
			true
		case .signIn:
			false
		}
	}

	var selectedGoal: OnboardingOption? {
		OnboardingOption.goals.first { $0.id == responses.selectedGoalID }
	}

	var selectedPainPoints: [OnboardingOption] {
		OnboardingOption.painPoints.filter { responses.selectedPainPointIDs.contains($0.id) }
	}

	var selectedPreferences: [OnboardingOption] {
		OnboardingOption.preferences.filter { responses.selectedPreferenceIDs.contains($0.id) }
	}

	func advance() {
		guard canContinue, !isOnFinalPage else { return }
		currentIndex += 1
	}

	func completeProcessing() {
		guard currentStep == .processing else { return }
		guard !isOnFinalPage else { return }
		currentIndex += 1
	}

	func selectSingle(_ option: OnboardingOption, for kind: OnboardingOptionKind) {
		switch kind {
		case .goal:
			responses.selectedGoalID = option.id
		case .painPoint:
			responses.selectedPainPointIDs = [option.id]
		case .preference:
			responses.selectedPreferenceIDs = [option.id]
		}
	}

	func toggle(_ option: OnboardingOption, for kind: OnboardingOptionKind) {
		switch kind {
		case .goal:
			responses.selectedGoalID = option.id
		case .painPoint:
			toggle(option.id, in: &responses.selectedPainPointIDs)
		case .preference:
			toggle(option.id, in: &responses.selectedPreferenceIDs)
		}
	}

	func isSelected(_ option: OnboardingOption, for kind: OnboardingOptionKind) -> Bool {
		switch kind {
		case .goal:
			responses.selectedGoalID == option.id
		case .painPoint:
			responses.selectedPainPointIDs.contains(option.id)
		case .preference:
			responses.selectedPreferenceIDs.contains(option.id)
		}
	}

	@discardableResult
	func recordCompletedDemoAction() -> Bool {
		guard currentStep == .demo else { return false }
		guard completedDemoActions < demoActionTarget else { return true }

		completedDemoActions += 1
		return completedDemoActions >= demoActionTarget
	}

	func completeDemoIfReady() {
		guard currentStep == .demo else { return }
		guard completedDemoActions >= demoActionTarget else { return }
		guard !isOnFinalPage else { return }

		currentIndex += 1
	}

	#if DEBUG
		func skipDemoForDebug() {
			guard currentStep == .demo else { return }
			completedDemoActions = demoActionTarget
		}

		/// Jumps directly to a step with seeded answers, for UI-test screenshots.
		func jumpForUITest(to step: OnboardingStep, responses seeded: OnboardingResponses) {
			currentIndex = step.rawValue
			responses = seeded
			if step == .demo {
				completedDemoActions = 0
			}
		}
	#endif

	private func toggle(_ id: String, in set: inout Set<String>) {
		if set.contains(id) {
			set.remove(id)
		} else {
			set.insert(id)
		}
	}
}

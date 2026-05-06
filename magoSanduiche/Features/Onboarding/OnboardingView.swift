//
//  OnboardingView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI
import Foundation

struct OnboardingView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@AppStorage("hasUnlockedFullGame") private var hasUnlockedFullGame = false
	@State private var vm = OnboardingViewModel()

	var body: some View {
		@Bindable var vm = vm

		AppLayout(
			background: .gradient,
			contentPadding: EdgeInsets(top: 18, leading: 0, bottom: 18, trailing: 0)
		) {
			VStack(spacing: 16) {
				OnboardingProgressView(progress: vm.progress, text: vm.progressText)
					.padding(.horizontal, 24)

				ScrollView {
					VStack(spacing: 18) {
						screenContent(vm: vm)
							.id(vm.currentStep)
							.terminalPanelTransition(edge: .bottom)
					}
					.padding(.horizontal, 20)
					.padding(.vertical, 8)
				}

				if vm.shouldShowPrimaryButton {
					Button(action: handlePrimaryAction) {
						Text(vm.primaryButtonTitle)
							.font(.monocraft(relativeTo: .headline, weight: .semibold))
							.frame(maxWidth: .infinity)
							.padding(.vertical, 14)
					}
					.buttonStyle(OnboardingPrimaryButtonStyle())
					.disabled(!vm.canContinue)
					.opacity(vm.canContinue ? 1 : 0.45)
					.padding(.horizontal, 24)
					.terminalPanelTransition(edge: .bottom)
				}
			}
		}
		.task(id: vm.currentStep) {
			AppAnalytics.capture("onboarding_step_viewed", properties: onboardingProperties)
			await advanceAfterProcessingIfNeeded()
		}
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private func handlePrimaryAction() {
		AppAnalytics.capture("onboarding_primary_tapped", properties: onboardingProperties.merging([
			"can_continue": vm.canContinue,
			"is_final_page": vm.isOnFinalPage
		]) { _, new in new })

		if vm.isOnFinalPage {
			vm.persistResponsesOnUnlock()
			AppAnalytics.capture("onboarding_unlocked", properties: onboardingProperties)
			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
				hasUnlockedFullGame = true
				coordinator.popToRoot()
			}
		} else {
			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
				vm.advance()
			}
		}
	}

	private var onboardingProperties: [String: Any] {
		var properties: [String: Any] = [
			"step": String(describing: vm.currentStep),
			"step_index": vm.currentIndex,
			"progress": vm.progress,
			"selected_pain_point_ids": Array(vm.responses.selectedPainPointIDs),
			"selected_preference_ids": Array(vm.responses.selectedPreferenceIDs),
			"completed_demo_actions": vm.completedDemoActions,
			"demo_action_target": vm.demoActionTarget
		]
		if let selectedGoalID = vm.responses.selectedGoalID {
			properties["selected_goal_id"] = selectedGoalID
		}
		return properties
	}

	@ViewBuilder
	private func screenContent(vm: OnboardingViewModel) -> some View {
		switch vm.currentStep {
		case .welcome:
			WelcomeOnboardingScreen()
		case .goal:
			QuestionScreen(
				kicker: String(localized: "nan_onboarding_kicker_player_intent"),
				title: String(localized: "nan_onboarding_goal_title"),
				subtitle: String(localized: "nan_onboarding_goal_subtitle"),
				options: OnboardingOption.goals,
				kind: .goal,
				allowsMultipleSelection: false,
				vm: vm
			)
		case .painPoints:
			QuestionScreen(
				kicker: String(localized: "nan_onboarding_kicker_curses"),
				title: String(localized: "nan_onboarding_pain_title"),
				subtitle: String(localized: "nan_onboarding_pain_subtitle"),
				options: OnboardingOption.painPoints,
				kind: .painPoint,
				allowsMultipleSelection: true,
				vm: vm
			)
		case .socialProof:
			SocialProofScreen()
		case .solution:
			PersonalizedSolutionScreen(vm: vm)
		case .preferences:
			QuestionScreen(
				kicker: String(localized: "nan_onboarding_kicker_flavor"),
				title: String(localized: "nan_onboarding_pref_title"),
				subtitle: String(localized: "nan_onboarding_pref_subtitle"),
				options: OnboardingOption.preferences,
				kind: .preference,
				allowsMultipleSelection: true,
				vm: vm
			)
		case .processing:
			ProcessingOnboardingScreen()
		case .demo:
			DemoOnboardingScreen(vm: vm)
		case .paywall:
			PaywallOnboardingScreen()
		}
	}

	private func advanceAfterProcessingIfNeeded() async {
		guard vm.currentStep == .processing else { return }
		try? await Task.sleep(for: .milliseconds(1500))
		guard !Task.isCancelled else { return }

		await MainActor.run {
			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
				vm.completeProcessing()
			}
		}
	}
}

private struct OnboardingProgressView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let progress: Double
	let text: String

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text("nan_onboarding_progress_label")
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
					.foregroundStyle(Color.accent)
				Spacer()
				Text(text)
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
					.foregroundStyle(Color.terminalMutedText)
			}

			GeometryReader { geometry in
				ZStack(alignment: .leading) {
					Rectangle()
						.fill(Color.terminalSurface)
					Rectangle()
						.fill(Color.accent)
						.frame(width: geometry.size.width * progress)
				}
			}
			.frame(height: 8)
			.drawBorder(nil, color: Color.accent.opacity(0.7), lineWidth: 1)
			.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation), value: progress)
		}
	}
}

private struct WelcomeOnboardingScreen: View {
	var body: some View {
		VStack(spacing: 18) {
			Image(.bread)
				.resizable()
				.interpolation(.none)
				.scaledToFit()
				.frame(height: 132)
				.foregroundStyle(.accent)
				.shadow(color: Color.accent.opacity(0.32), radius: 14)

			Text("nan_onboarding_welcome_title")
				.font(.monocraft(relativeTo: .title2, weight: .bold))
				.multilineTextAlignment(.center)
				.foregroundStyle(Color.accent)

			Text("nan_onboarding_welcome_body")
				.font(.monocraft(relativeTo: .body))
				.multilineTextAlignment(.center)
				.foregroundStyle(Color.terminalMutedText)

		}
		.padding(.top, 8)
	}
}



private struct QuestionScreen: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let kicker: String
	let title: String
	let subtitle: String
	let options: [OnboardingOption]
	let kind: OnboardingOptionKind
	let allowsMultipleSelection: Bool
	let vm: OnboardingViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			OnboardingHeader(kicker: kicker, title: title, subtitle: subtitle)

			VStack(spacing: 10) {
				ForEach(options) { option in
					OptionCard(
						option: option,
						isSelected: vm.isSelected(option, for: kind),
						allowsMultipleSelection: allowsMultipleSelection
					) {
						AppAnalytics.capture("onboarding_option_selected", properties: [
							"step": String(describing: vm.currentStep),
							"option_kind": String(describing: kind),
							"option_id": option.id,
							"allows_multiple_selection": allowsMultipleSelection,
							"was_selected": vm.isSelected(option, for: kind)
						])
						TerminalMotion.perform(reduceMotion: reduceMotion, animation: .snappy(duration: 0.22)) {
							allowsMultipleSelection ? vm.toggle(option, for: kind) : vm.selectSingle(option, for: kind)
						}
					}
				}
			}
		}
	}
}

private struct OptionCard: View {
	let option: OnboardingOption
	let isSelected: Bool
	let allowsMultipleSelection: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 12) {
				Image(option.image)
					.resizable()
					.interpolation(.none)
					.scaledToFit()
					.frame(width: 34, height: 34)
					.foregroundStyle(isSelected ? Color.terminalWarning : Color.accent)

				VStack(alignment: .leading, spacing: 5) {
					Text(option.title)
						.font(.monocraft(relativeTo: .headline, weight: .semibold))
						.foregroundStyle(isSelected ? Color.terminalWarning : Color.accent)
					Text(option.subtitle)
						.font(.monocraft(relativeTo: .caption))
						.foregroundStyle(Color.terminalMutedText)
						.multilineTextAlignment(.leading)
				}

				Spacer(minLength: 0)

				Text(selectionMark)
					.font(.monocraft(relativeTo: .headline, weight: .bold))
					.foregroundStyle(isSelected ? Color.terminalWarning : Color.terminalMutedText)
			}
			.padding(12)
			.background(isSelected ? Color.terminalActiveSurface : Color.terminalSurface)
			.drawBorder(nil, color: isSelected ? .terminalWarning : .accent.opacity(0.65), lineWidth: isSelected ? 2 : 1)
		}
		.buttonStyle(.plain)
	}

	private var selectionMark: String {
		if allowsMultipleSelection {
			isSelected ? "[x]" : "[ ]"
		} else {
			isSelected ? "(*)" : "( )"
		}
	}
}

private struct SocialProofScreen: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			OnboardingHeader(
				kicker: String(localized: "nan_onboarding_kicker_reports"),
				title: String(localized: "nan_onboarding_social_title"),
				subtitle: String(localized: "nan_onboarding_social_subtitle")
			)

			ForEach(OnboardingTestimonial.placeholders) { testimonial in
				VStack(alignment: .leading, spacing: 8) {
					Text("*****")
						.font(.monocraft(relativeTo: .caption, weight: .bold))
						.foregroundStyle(Color.terminalWarning)
					Text(
						String(
							format: String(localized: "nan_onboarding_testimonial_quote_format"),
							testimonial.quote
						)
					)
						.font(.monocraft(relativeTo: .callout))
						.foregroundStyle(Color.accent)
					Text(
						String(
							format: String(localized: "nan_onboarding_testimonial_attribution_format"),
							testimonial.player,
							testimonial.persona
						)
					)
						.font(.monocraft(relativeTo: .caption2, weight: .semibold))
						.foregroundStyle(Color.terminalMutedText)
				}
				.padding(14)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color.terminalSurface)
				.drawBorder(nil, color: .accent.opacity(0.65), lineWidth: 1)
			}
		}
	}
}

private struct PersonalizedSolutionScreen: View {
	let vm: OnboardingViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			OnboardingHeader(
				kicker: String(localized: "nan_onboarding_kicker_spell"),
				title: String(
					format: String(localized: "nan_onboarding_solution_title_format"),
					vm.selectedGoal?.title ?? String(localized: "nan_onboarding_solution_fallback_goal")
				),
				subtitle: String(localized: "nan_onboarding_solution_subtitle")
			)

			ForEach(solutionRows) { solution in
				HStack(alignment: .top, spacing: 12) {
					Image(solution.image)
						.resizable()
						.interpolation(.none)
						.scaledToFit()
						.frame(width: 30, height: 30)
						.foregroundStyle(Color.terminalMana)

					VStack(alignment: .leading, spacing: 5) {
						Text(solution.pain)
							.font(.monocraft(relativeTo: .caption, weight: .semibold))
							.foregroundStyle(Color.terminalMutedText)
						Text(solution.promise)
							.font(.monocraft(relativeTo: .callout, weight: .semibold))
							.foregroundStyle(Color.accent)
					}
				}
				.padding(12)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color.terminalSurface)
				.drawBorder(nil, color: .terminalMana.opacity(0.75), lineWidth: 1)
			}
		}
	}

	private var solutionRows: [OnboardingSolution] {
		if vm.selectedPainPoints.isEmpty {
			return OnboardingSolution.defaults
		}

		let mirrored = vm.selectedPainPoints.prefix(3).map { painPoint in
			OnboardingSolution(
				pain: painPoint.title,
				promise: promise(for: painPoint.id),
				image: painPoint.image
			)
		}

		return Array(mirrored)
	}

	private func promise(for painPointID: String) -> String {
		switch painPointID {
		case "too_many_rules":
			String(localized: "nan_onboarding_promise_too_many_rules")
		case "slow_setup":
			String(localized: "nan_onboarding_promise_slow_setup")
		case "generic_stories":
			String(localized: "nan_onboarding_promise_generic_stories")
		case "no_group":
			String(localized: "nan_onboarding_promise_no_group")
		case "boring_choices":
			String(localized: "nan_onboarding_promise_boring_choices")
		default:
			String(localized: "nan_onboarding_promise_default")
		}
	}
}

private struct ProcessingOnboardingScreen: View {
	var body: some View {
		VStack(spacing: 18) {
			Image(.cards)
				.resizable()
				.interpolation(.none)
				.scaledToFit()
				.frame(height: 120)
				.foregroundStyle(Color.terminalWarning)

			OnboardingHeader(
				kicker: String(localized: "nan_onboarding_kicker_compiler"),
				title: String(localized: "nan_onboarding_processing_title"),
				subtitle: String(localized: "nan_onboarding_processing_subtitle")
			)

			HStack {
				Text(String(localized: "nan_onboarding_processing_flavor"))
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
					.foregroundStyle(Color.terminalWarning)
				InlineTerminalDots()
				Spacer()
			}
			.padding(14)
			.background(Color.terminalSurface)
			.drawBorder(nil, color: .terminalWarning, lineWidth: 1)
		}
		.frame(maxWidth: .infinity)
	}
}

private struct DemoOnboardingScreen: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	let vm: OnboardingViewModel
	@State private var gameVM = GameViewModel()
	@State private var demoCoordinator = AppCoordinator()
	@State private var isDemoPresented = false
	@State private var hasAutoPresentedDemo = false

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			OnboardingHeader(
				kicker: String(localized: "nan_onboarding_kicker_demo"),
				title: String(localized: "nan_onboarding_demo_title"),
				subtitle: String(
					format: String(localized: "nan_onboarding_demo_subtitle_format"),
					vm.demoActionTarget
				)
			)

			Text(
				String(
					format: String(localized: "nan_onboarding_demo_actions_chip_format"),
					vm.demoProgressText
				)
			)
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(Color.terminalWarning)
				.frame(maxWidth: .infinity, alignment: .leading)

			VStack(alignment: .leading, spacing: 10) {
				Text(String(localized: "nan_onboarding_demo_bullet_fullscreen"))
					.font(.monocraft(relativeTo: .callout))
					.foregroundStyle(Color.accent)
				Text(String(localized: "nan_onboarding_demo_bullet_resume"))
					.font(.monocraft(relativeTo: .caption))
					.foregroundStyle(Color.terminalMutedText)
			}
			.padding(14)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color.terminalSurface)
			.drawBorder(String(localized: "nan_onboarding_demo_mode_border"), color: .terminalMana, lineWidth: 1)

			Button {
				AppAnalytics.capture("onboarding_demo_opened", properties: [
					"completed_demo_actions": vm.completedDemoActions,
					"demo_action_target": vm.demoActionTarget,
					"is_resume": vm.completedDemoActions > 0
				])
				isDemoPresented = true
			} label: {
				Text(
					String(
						format: String(localized: "nan_onboarding_demo_cta_format"),
						vm.completedDemoActions == 0
							? String(localized: "nan_onboarding_demo_cta_start")
							: String(localized: "nan_onboarding_demo_cta_resume")
					)
				)
					.font(.monocraft(relativeTo: .headline, weight: .semibold))
					.frame(maxWidth: .infinity)
					.padding(.vertical, 14)
			}
			.buttonStyle(OnboardingPrimaryButtonStyle())
		}
		.onAppear {
			guard vm.completedDemoActions < vm.demoActionTarget else { return }
			guard !hasAutoPresentedDemo else { return }
			hasAutoPresentedDemo = true
			AppAnalytics.capture("onboarding_demo_auto_presented", properties: [
				"completed_demo_actions": vm.completedDemoActions,
				"demo_action_target": vm.demoActionTarget
			])
			isDemoPresented = true
		}
		.fullScreenCover(isPresented: $isDemoPresented) {
			DemoGameCover(
				vm: vm,
				gameVM: gameVM,
				demoCoordinator: demoCoordinator,
				onCompletedPlayerAction: handleCompletedPlayerAction
			) {
				AppAnalytics.capture("onboarding_demo_closed", properties: [
					"completed_demo_actions": vm.completedDemoActions,
					"demo_action_target": vm.demoActionTarget
				])
				isDemoPresented = false
			}
		}
	}

	private func handleCompletedPlayerAction() {
		let shouldShowPaywall = vm.recordCompletedDemoAction()
		AppAnalytics.capture("onboarding_demo_action_completed", properties: [
			"completed_demo_actions": vm.completedDemoActions,
			"demo_action_target": vm.demoActionTarget,
			"did_complete_demo": shouldShowPaywall
		])
		guard shouldShowPaywall else { return }

		AppAnalytics.capture("onboarding_demo_completed", properties: [
			"completed_demo_actions": vm.completedDemoActions,
			"demo_action_target": vm.demoActionTarget
		])
		isDemoPresented = false
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(250))
			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
				vm.completeDemoIfReady()
			}
		}
	}
}

private struct DemoGameCover: View {
	let vm: OnboardingViewModel
	let gameVM: GameViewModel
	let demoCoordinator: AppCoordinator
	let onCompletedPlayerAction: () -> Void
	let onClose: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 12) {
				Text(
					String(
						format: String(localized: "nan_onboarding_demo_actions_chip_format"),
						vm.demoProgressText
					)
				)
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
					.foregroundStyle(Color.terminalWarning)

				Spacer()

				Button(action: onClose) {
					Text(String(localized: "nan_onboarding_demo_exit"))
						.font(.monocraft(relativeTo: .caption, weight: .semibold))
						.foregroundStyle(Color.terminalMana)
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			.background(Color.terminalSurface)
			.drawBorder(nil, color: .terminalMana, lineWidth: 1)

			GameSessionView(
				vm: gameVM,
				coordinator: demoCoordinator,
				showsTips: false,
				onCompletedPlayerAction: onCompletedPlayerAction
			)
		}
		.background(Color.background.ignoresSafeArea())
	}
}

private struct PaywallOnboardingScreen: View {
	var body: some View {
		VStack(spacing: 16) {
			Image(.bread)
				.resizable()
				.interpolation(.none)
				.scaledToFit()
				.frame(height: 108)
				.foregroundStyle(Color.terminalWarning)
				.shadow(color: Color.terminalWarning.opacity(0.24), radius: 12)

			OnboardingHeader(
				kicker: String(localized: "nan_onboarding_kicker_paywall"),
				title: String(localized: "nan_onboarding_paywall_title"),
				subtitle: String(localized: "nan_onboarding_paywall_subtitle")
			)

			VStack(alignment: .leading, spacing: 12) {
				PaywallBullet(text: String(localized: "nan_onboarding_paywall_bullet_turns"))
				PaywallBullet(text: String(localized: "nan_onboarding_paywall_bullet_reactive"))
				PaywallBullet(text: String(localized: "nan_onboarding_paywall_bullet_content"))
			}
			.padding(14)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color.terminalSurface)
			.drawBorder(String(localized: "nan_onboarding_paywall_included_border"), color: .accent, lineWidth: 1)

			VStack(spacing: 8) {
				Text(String(localized: "nan_onboarding_paywall_price"))
					.font(.monocraft(relativeTo: .headline, weight: .bold))
					.foregroundStyle(Color.terminalWarning)
				Text(String(localized: "nan_onboarding_paywall_disclaimer"))
					.font(.monocraft(relativeTo: .caption))
					.multilineTextAlignment(.center)
					.foregroundStyle(Color.terminalMutedText)
				Button(String(localized: "nan_onboarding_paywall_restore")) {
					AppAnalytics.capture("onboarding_paywall_restore_tapped")
				}
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
					.foregroundStyle(Color.terminalMana)
			}
			.padding(14)
			.frame(maxWidth: .infinity)
			.background(Color.terminalSurface)
			.drawBorder(String(localized: "nan_onboarding_paywall_trial_border"), color: .terminalWarning, lineWidth: 1)
		}
	}
}

private struct PaywallBullet: View {
	let text: String

	var body: some View {
		HStack(alignment: .top, spacing: 10) {
			Text("[x]")
				.font(.monocraft(relativeTo: .caption, weight: .bold))
				.foregroundStyle(Color.terminalWarning)
			Text(text)
				.font(.monocraft(relativeTo: .callout))
				.foregroundStyle(Color.accent)
		}
	}
}

private struct OnboardingHeader: View {
	let kicker: String
	let title: String
	let subtitle: String

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(kicker)
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(Color.terminalMana)
			Text(title)
				.font(.monocraft(relativeTo: .title3, weight: .bold))
				.foregroundStyle(Color.accent)
				.fixedSize(horizontal: false, vertical: true)
			Text(subtitle)
				.font(.monocraft(relativeTo: .callout))
				.foregroundStyle(Color.terminalMutedText)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

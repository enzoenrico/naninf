//
//  OnboardingPage.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI
import Foundation

enum OnboardingStep: Int, CaseIterable {
	case welcome
	case goal
	case painPoints
	case socialProof
	case solution
	case preferences
	case processing
	case demo
	case paywall
}

enum OnboardingOptionKind {
	case goal
	case painPoint
	case preference
}

struct OnboardingOption: Identifiable, Hashable {
	let id: String
	let title: String
	let subtitle: String
	let image: ImageResource
}

struct OnboardingTestimonial: Identifiable {
	let id = UUID()
	let player: String
	let persona: String
	let quote: String
}

struct OnboardingSolution: Identifiable {
	let id = UUID()
	let pain: String
	let promise: String
	let image: ImageResource
}

struct OnboardingResponses: Codable {
	var selectedGoalID: String?
	var selectedPainPointIDs: Set<String> = []
	var selectedPreferenceIDs: Set<String> = []
}

extension OnboardingOption {
	static let goals: [OnboardingOption] = [
		.init(
			id: "quick_escape",
			title: String(localized: "nan_onboarding_option_quick_escape_title"),
			subtitle: String(localized: "nan_onboarding_option_quick_escape_subtitle"),
			image: .bread
		),
		.init(
			id: "clever_puzzle",
			title: String(localized: "nan_onboarding_option_clever_puzzle_title"),
			subtitle: String(localized: "nan_onboarding_option_clever_puzzle_subtitle"),
			image: .search
		),
		.init(
			id: "dangerous_combat",
			title: String(localized: "nan_onboarding_option_dangerous_combat_title"),
			subtitle: String(localized: "nan_onboarding_option_dangerous_combat_subtitle"),
			image: .dice
		),
		.init(
			id: "magic_roleplay",
			title: String(localized: "nan_onboarding_option_magic_roleplay_title"),
			subtitle: String(localized: "nan_onboarding_option_magic_roleplay_subtitle"),
			image: .ink
		),
		.init(
			id: "chaotic_sandbox",
			title: String(localized: "nan_onboarding_option_chaotic_sandbox_title"),
			subtitle: String(localized: "nan_onboarding_option_chaotic_sandbox_subtitle"),
			image: .cards
		),
	]

	static let painPoints: [OnboardingOption] = [
		.init(
			id: "too_many_rules",
			title: String(localized: "nan_onboarding_option_too_many_rules_title"),
			subtitle: String(localized: "nan_onboarding_option_too_many_rules_subtitle"),
			image: .cards
		),
		.init(
			id: "slow_setup",
			title: String(localized: "nan_onboarding_option_slow_setup_title"),
			subtitle: String(localized: "nan_onboarding_option_slow_setup_subtitle"),
			image: .ink
		),
		.init(
			id: "generic_stories",
			title: String(localized: "nan_onboarding_option_generic_stories_title"),
			subtitle: String(localized: "nan_onboarding_option_generic_stories_subtitle"),
			image: .search
		),
		.init(
			id: "no_group",
			title: String(localized: "nan_onboarding_option_no_group_title"),
			subtitle: String(localized: "nan_onboarding_option_no_group_subtitle"),
			image: .bread
		),
		.init(
			id: "boring_choices",
			title: String(localized: "nan_onboarding_option_boring_choices_title"),
			subtitle: String(localized: "nan_onboarding_option_boring_choices_subtitle"),
			image: .dice
		),
	]

	static let preferences: [OnboardingOption] = [
		.init(
			id: "spooky",
			title: String(localized: "nan_onboarding_option_spooky_title"),
			subtitle: String(localized: "nan_onboarding_option_spooky_subtitle"),
			image: .search
		),
		.init(
			id: "funny",
			title: String(localized: "nan_onboarding_option_funny_title"),
			subtitle: String(localized: "nan_onboarding_option_funny_subtitle"),
			image: .bread
		),
		.init(
			id: "heroic",
			title: String(localized: "nan_onboarding_option_heroic_title"),
			subtitle: String(localized: "nan_onboarding_option_heroic_subtitle"),
			image: .ink
		),
		.init(
			id: "mysterious",
			title: String(localized: "nan_onboarding_option_mysterious_title"),
			subtitle: String(localized: "nan_onboarding_option_mysterious_subtitle"),
			image: .cards
		),
		.init(
			id: "risky",
			title: String(localized: "nan_onboarding_option_risky_title"),
			subtitle: String(localized: "nan_onboarding_option_risky_subtitle"),
			image: .dice
		),
	]
}

extension OnboardingTestimonial {
	static let placeholders: [OnboardingTestimonial] = [
		.init(
			player: "M.",
			persona: String(localized: "nan_onboarding_testimonial_m_persona"),
			quote: String(localized: "nan_onboarding_testimonial_m_quote")
		),
		.init(
			player: "R.",
			persona: String(localized: "nan_onboarding_testimonial_r_persona"),
			quote: String(localized: "nan_onboarding_testimonial_r_quote")
		),
		.init(
			player: "L.",
			persona: String(localized: "nan_onboarding_testimonial_l_persona"),
			quote: String(localized: "nan_onboarding_testimonial_l_quote")
		),
	]
}

extension OnboardingSolution {
	static let defaults: [OnboardingSolution] = [
		.init(
			pain: String(localized: "nan_onboarding_solution_default_rules_pain"),
			promise: String(localized: "nan_onboarding_solution_default_rules_promise"),
			image: .ink
		),
		.init(
			pain: String(localized: "nan_onboarding_solution_default_solo_pain"),
			promise: String(localized: "nan_onboarding_solution_default_solo_promise"),
			image: .bread
		),
		.init(
			pain: String(localized: "nan_onboarding_solution_default_teeth_pain"),
			promise: String(localized: "nan_onboarding_solution_default_teeth_promise"),
			image: .dice
		),
	]
}

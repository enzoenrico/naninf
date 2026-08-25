//
//  ProfileView.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import Foundation
import SwiftUI

struct ProfileView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Environment(AuthSessionStore.self) private var authSessionStore
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@AppStorage("onboardingResponses") private var onboardingResponsesData: Data = Data()
	@AppStorage("unlockDate") private var unlockTimestamp: Double = 0
	@AppStorage("runsStarted") private var runsStarted: Int = 0
	@AppStorage("runsVictories") private var runsVictories: Int = 0
	@AppStorage("runsDefeats") private var runsDefeats: Int = 0
	@AppStorage("bestStreak") private var bestStreak: Int = 0

	@State private var countersHydrated = false

	var body: some View {
		AppLayout(background: .solid, scrollable: true) {
			VStack(alignment: .leading, spacing: 18) {
				header
				ProfileSection(title: String(localized: "nan_profile_section_identity"), accent: .accent) {
					ProfileKeyValueRow(
						key: String(localized: "nan_profile_key_callsign"),
						value: String(localized: "nan_profile_value_wizard"))
					if let loginSnapshot = authSessionStore.loginSnapshot {
						ProfileKeyValueRow(
							key: String(localized: "nan_profile_key_account"),
							value: loginSnapshot.email ?? loginSnapshot.userID,
							valueColor: .terminalMana
						)
						ProfileKeyValueRow(
							key: String(localized: "nan_profile_key_provider"),
							value: loginSnapshot.provider.rawValue.uppercased(),
							valueColor: .terminalWarning
						)
					}
					ProfileKeyValueRow(
						key: String(localized: "nan_profile_key_unlocked"),
						value: unlockedDateString,
						valueColor: .terminalMana
					)
					ProfileKeyValueRow(
						key: String(localized: "nan_profile_key_status"),
						value: String(localized: "nan_profile_value_active"),
						valueColor: .terminalWarning
					)
				}

				ProfileCreditsSection()

				ProfileSection(title: String(localized: "nan_profile_section_traits"), accent: .terminalMana) {
					if traitRows.isEmpty {
						Text("nan_profile_traits_empty")
							.font(.monocraft(relativeTo: .caption, weight: .semibold))
							.foregroundStyle(Color.terminalMutedText)
					} else {
						ForEach(traitRows, id: \.key) { row in
							ProfileKeyValueRow(
								key: row.key,
								value: row.value,
								valueColor: row.color
							)
						}
					}
				}

				ProfileSection(title: String(localized: "nan_profile_section_counters"), accent: .terminalWarning) {
					ProfileCounterRow(
						key: String(localized: "nan_profile_key_runs_started"), value: runsStarted,
						isLoading: !countersHydrated)
					ProfileCounterRow(
						key: String(localized: "nan_profile_key_victories"), value: runsVictories,
						isLoading: !countersHydrated)
					ProfileCounterRow(
						key: String(localized: "nan_profile_key_defeats"), value: runsDefeats,
						isLoading: !countersHydrated)
					ProfileCounterRow(
						key: String(localized: "nan_profile_key_best_streak"), value: bestStreak,
						isLoading: !countersHydrated)

					Text("nan_profile_counters_footnote")
						.font(.monocraft(relativeTo: .caption2, weight: .semibold))
						.foregroundStyle(Color.terminalMutedText)
						.padding(.top, 4)
				}

				Spacer(minLength: 12)

				signOutButton
				backButton
			}
		}
		.task(id: reduceMotion) {
			await hydrateCounters()
		}
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	// MARK: - Sections

	private var header: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("nan_profile_header_kicker")
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(Color.terminalMana)
			Text("nan_profile_title")
				.font(.monocraft(relativeTo: .title3, weight: .bold))
				.foregroundStyle(Color.accent)
				.fixedSize(horizontal: false, vertical: true)
			Text("nan_profile_subtitle")
				.font(.monocraft(relativeTo: .callout))
				.foregroundStyle(Color.terminalMutedText)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var backButton: some View {
		Button {
			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
				coordinator.back()
			}
		} label: {
			Text("nan_profile_back")
				.font(.monocraft(relativeTo: .headline, weight: .semibold))
				.frame(maxWidth: .infinity)
				.padding(.vertical, 14)
		}
		.buttonStyle(OnboardingPrimaryButtonStyle())
		.accessibilityHint(String(localized: "nan_profile_back_a11y"))
	}

	private var signOutButton: some View {
		Button {
			Task { @MainActor in
				await authSessionStore.signOut()
				TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
					coordinator.popToRoot()
				}
			}
		} label: {
			HStack(spacing: 8) {
				Text("nan_profile_sign_out")
					.font(.monocraft(relativeTo: .headline, weight: .semibold))
				if authSessionStore.isAuthenticating {
					TerminalGlyphLoader(style: .blocks, textStyle: .caption, color: .terminalDanger)
						.accessibilityHidden(true)
				}
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 14)
		}
		.buttonStyle(.plain)
		.foregroundStyle(Color.terminalDanger)
		.drawBorder(nil, color: .terminalDanger, lineWidth: 2)
		.opacity(authSessionStore.isAuthenticating ? 0.7 : 1)
		.disabled(authSessionStore.isAuthenticating)
		.accessibilityHint(String(localized: "nan_profile_sign_out_a11y"))
	}

	// MARK: - Data

	private struct TraitRow {
		let key: String
		let value: String
		let color: Color
	}

	private var decodedResponses: OnboardingResponses? {
		guard !onboardingResponsesData.isEmpty else { return nil }
		return try? JSONDecoder().decode(OnboardingResponses.self, from: onboardingResponsesData)
	}

	private var traitRows: [TraitRow] {
		guard let responses = decodedResponses else { return [] }

		var rows: [TraitRow] = []

		if let goalID = responses.selectedGoalID,
			let goal = OnboardingOption.goals.first(where: { $0.id == goalID })
		{
			rows.append(TraitRow(key: String(localized: "nan_profile_key_goal"), value: goal.title, color: .accent))
		}

		let painLabels = OnboardingOption.painPoints
			.filter { responses.selectedPainPointIDs.contains($0.id) }
			.map(\.title)
		if !painLabels.isEmpty {
			rows.append(
				TraitRow(
					key: String(localized: "nan_profile_key_curses"),
					value: painLabels.joined(separator: ", "),
					color: .terminalDanger
				)
			)
		}

		let preferenceLabels = OnboardingOption.preferences
			.filter { responses.selectedPreferenceIDs.contains($0.id) }
			.map(\.title)
		if !preferenceLabels.isEmpty {
			rows.append(
				TraitRow(
					key: String(localized: "nan_profile_key_flavor"),
					value: preferenceLabels.joined(separator: ", "),
					color: .terminalWarning
				)
			)
		}

		return rows
	}

	private var unlockedDateString: String {
		guard unlockTimestamp > 0 else { return "—" }
		let date = Date(timeIntervalSince1970: unlockTimestamp)
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy.MM.dd"
		return formatter.string(from: date)
	}

	private func hydrateCounters() async {
		countersHydrated = false
		guard !reduceMotion else {
			countersHydrated = true
			return
		}

		try? await Task.sleep(for: .milliseconds(600))
		guard !Task.isCancelled else { return }

		TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
			countersHydrated = true
		}
	}
}

#Preview {
	ProfileView()
		.environment(AppCoordinator())
		.environment(AuthSessionStore())
		.environment(CreditWalletStore())
}

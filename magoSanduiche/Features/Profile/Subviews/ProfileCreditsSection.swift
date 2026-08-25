//
//  ProfileCreditsSection.swift
//  magoSanduiche
//

import SwiftUI

struct ProfileCreditsSection: View {
	@Environment(CreditWalletStore.self) private var creditWallet
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ProfileSection(title: String(localized: "nan_profile_section_credits"), accent: .terminalMana) {
			ProfileKeyValueRow(
				key: String(localized: "nan_profile_key_credits"),
				value: creditWallet.isLoadingWallet
					? String(localized: "nan_profile_counter_loading")
					: creditWallet.formattedBalance,
				valueColor: .terminalMana
			)

			ProfileKeyValueRow(
				key: String(localized: "nan_profile_key_stipend"),
				value: creditWallet.hasActiveStipend
					? String(localized: "nan_profile_value_stipend_active")
					: String(localized: "nan_profile_value_stipend_none"),
				valueColor: creditWallet.hasActiveStipend ? .terminalWarning : .terminalMutedText
			)

			Text("nan_profile_credits_footnote")
				.font(.monocraft(relativeTo: .caption2, weight: .semibold))
				.foregroundStyle(Color.terminalMutedText)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.top, 2)

			if !creditWallet.canPurchase {
				Text("nan_credits_rc_key_hint")
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
					.foregroundStyle(Color.terminalWarning)
					.fixedSize(horizontal: false, vertical: true)
			}

			if creditWallet.isLoadingOfferings && creditWallet.packages.isEmpty {
				HStack {
					TerminalGlyphLoader(style: .blocks, textStyle: .caption, color: .terminalWarning)
					Text("nan_credits_loading_offerings")
						.font(.monocraft(relativeTo: .caption, weight: .semibold))
						.foregroundStyle(Color.terminalMutedText)
				}
				.padding(.top, 4)
			}

			ForEach(creditWallet.packages) { package in
				Button {
					Task { await creditWallet.purchase(package) }
				} label: {
					HStack(alignment: .firstTextBaseline, spacing: 10) {
						VStack(alignment: .leading, spacing: 2) {
							Text(LocalizedStringKey(package.kind.titleKey))
								.font(.monocraft(relativeTo: .callout, weight: .bold))
								.foregroundStyle(Color.accent)
							Text(LocalizedStringKey(package.kind.detailKey))
								.font(.monocraft(relativeTo: .caption2, weight: .semibold))
								.foregroundStyle(Color.terminalMutedText)
								.fixedSize(horizontal: false, vertical: true)
						}
						Spacer(minLength: 8)
						Text(package.localizedPrice)
							.font(.monocraft(relativeTo: .callout, weight: .bold))
							.foregroundStyle(Color.terminalMana)
					}
					.padding(.vertical, 8)
					.padding(.horizontal, 4)
				}
				.buttonStyle(.plain)
				.disabled(creditWallet.isPurchasing || !creditWallet.canPurchase)
				.opacity(creditWallet.isPurchasing ? 0.7 : 1)
				.drawBorder(nil, color: .terminalMana, lineWidth: 1)
			}

			Button {
				Task { await creditWallet.restorePurchases() }
			} label: {
				Text("nan_credits_restore")
					.font(.monocraft(relativeTo: .caption, weight: .bold))
					.frame(maxWidth: .infinity)
					.padding(.vertical, 10)
			}
			.buttonStyle(.plain)
			.foregroundStyle(Color.accent)
			.drawBorder(nil, color: .accent, lineWidth: 1)
			.disabled(creditWallet.isPurchasing || !creditWallet.canPurchase)
			.padding(.top, 4)

			if let status = creditWallet.statusMessage {
				Text(status)
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
					.foregroundStyle(Color.terminalMana)
			}
			if let error = creditWallet.lastErrorMessage {
				Text(error)
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
					.foregroundStyle(Color.terminalDanger)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.task {
			await creditWallet.refreshWallet()
			await creditWallet.refreshOfferings()
		}
	}
}

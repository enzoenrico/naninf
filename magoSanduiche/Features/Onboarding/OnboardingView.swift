//
//  OnboardingView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct OnboardingView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@State private var vm = OnboardingViewModel()

	var body: some View {
		@Bindable var vm = vm

		VStack(spacing: 18) {
			TabView(selection: $vm.currentIndex) {
				ForEach(vm.pages.indices, id: \.self) { index in
					OnboardingCard(page: vm.pages[index])
						.tag(index)
						.padding(.horizontal, 16)
				}
			}
			.tabViewStyle(.page)
			.indexViewStyle(.page(backgroundDisplayMode: .always))

//			PrologueCommandPanel(
//				command: vm.currentPage.command,
//				isFinalCommand: vm.isOnFinalPage
//			)
//			.padding(.horizontal, 24)

			Button(action: handlePrimaryAction) {
				Text(vm.primaryButtonTitle)
					.font(.monocraft(relativeTo: .headline, weight: .semibold))
					.frame(maxWidth: .infinity)
					.padding(.vertical, 14)
			}
			.buttonStyle(OnboardingPrimaryButtonStyle())
			.padding(.horizontal, 24)
		}
		.padding(.vertical, 28)
		.background {
			ZStack {
				Color.background
				LinearGradient(
					colors: [Color.accent.opacity(0.10), Color.clear, Color.terminalMana.opacity(0.08)],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			}
			.ignoresSafeArea()
		}
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	private func handlePrimaryAction() {
		if vm.isOnFinalPage {
			coordinator.navigate(to: .game)
		} else {
			withAnimation {
				_ = vm.advance()
			}
		}
	}
}

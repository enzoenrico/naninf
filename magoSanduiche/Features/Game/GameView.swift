//
//  GameView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI
import TipKit

struct GameView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@State private var actionAreaTip = ActionAreaTip()
	@State private var imageSectionTip = ImageSectionTip()
	@State private var actionButtonTip = ActionButtonTip()
	@State private var statBarsTip = StatBarsTip()
	@State private var tipsConfigured = false
	@State private var inlineResponseStatus: ResponseStatus?
	@State private var inlineStatusDismissTask: Task<Void, Never>?
	@State private var vm = GameViewModel()

	@AppStorage("hasSeenGameTips") private var hasSeenGameTips = false

	var body: some View {
		@Bindable var vm = vm
		@Bindable var coordinator = coordinator

		let shouldShowTips = !hasSeenGameTips

		VStack(spacing: 12) {
			GameHeader(
				health: vm.health,
				mana: vm.mana,
				maxHealth: vm.maxHealth,
				maxMana: vm.maxMana,
				phase: vm.uiPhase
			)
			.popoverTipIf(statBarsTip, arrowEdge: .bottom, when: shouldShowTips)
			.zIndex(2)

			VStack(spacing: 12) {
				sceneImage(coordinator: coordinator, vm: vm, shouldShowTips: shouldShowTips)
				actionPanel(coordinator: coordinator, vm: vm, shouldShowTips: shouldShowTips)
				actionButton(coordinator: coordinator, vm: vm, shouldShowTips: shouldShowTips)
			}
		}
		.navigationBarBackButtonHidden()
		.padding()
		.background {
			TerminalBackdrop()
				.ignoresSafeArea()
		}
		.animation(.snappy(duration: 0.28), value: inlineResponseStatus?.id)
		.tipViewStyle(AsciiTipStyle())
		.task {
			vm.attachCoordinator(coordinator)
			presentInlineStatus(for: vm.uiPhase)
			configureTipsIfNeeded(shouldShowTips: shouldShowTips)
		}
		.onChange(of: vm.uiPhase) { _, newPhase in
			presentInlineStatus(for: newPhase)
		}
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif

	@ViewBuilder
	private func sceneImage(
		coordinator: AppCoordinator,
		vm: GameViewModel,
		shouldShowTips: Bool
	) -> some View {
		if coordinator.isImageCollapsed {
			CollapsedVisionBar {
				withAnimation(.snappy(duration: 0.35)) {
					coordinator.toggleImage()
				}
			}
		} else {
			VisionPanel(
				isCollapsed: coordinator.isImageCollapsed,
				isLoading: vm.loading,
				phase: vm.uiPhase
			)
			.popoverTipIf(imageSectionTip, arrowEdge: .top, when: shouldShowTips)
			.transition(.move(edge: .top).combined(with: .opacity))
			.onTapGesture {
				withAnimation(.snappy(duration: 0.35)) {
					coordinator.toggleImage()
				}
			}
		}
	}

	private func actionPanel(
		coordinator: AppCoordinator,
		vm: GameViewModel,
		shouldShowTips: Bool
	) -> some View {
		ActionStack(title: vm.uiPhase.actionTitle) {
			if coordinator.isDicePromptVisible {
				DicePromptView(
					diceValue: vm.diceValue,
					resultText: vm.diceResultText,
					isRolling: vm.uiPhase == .rollingDice && vm.loading
				)
			} else {
				terminalPanel(coordinator: coordinator, vm: vm)
			}
		}
		.popoverTipIf(actionAreaTip, arrowEdge: .top, when: shouldShowTips)
		.frame(maxWidth: .infinity)
		.layoutPriority(1)
	}

	private func terminalPanel(coordinator: AppCoordinator, vm: GameViewModel) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			if let inlineResponseStatus {
				InlineResponseStatusRow(status: inlineResponseStatus) {
					dismissInlineStatus()
				}
				.transition(.move(edge: .top).combined(with: .opacity))
			}

			TypeWriterView(vm.narrativeText) {
				vm.markNarrativeFinished()
				coordinator.handleTypewriterCompletion()
			}
			.padding(.horizontal, 4)

			if coordinator.isContextualInputVisible {
				InputBox(
					with: Binding(
						get: { vm.contextualInput },
						set: { vm.contextualInput = $0 }
					),
					isDisabled: vm.loading,
					invalidAttempts: vm.invalidInputAttempts
				) {
					submitPrimaryAction(vm: vm, coordinator: coordinator)
				}
				.transition(.move(edge: .bottom).combined(with: .opacity))
			}
		}
		.padding(12)
	}

	@ViewBuilder
	private func actionButton(
		coordinator: AppCoordinator,
		vm: GameViewModel,
		shouldShowTips: Bool
	) -> some View {
		if coordinator.showActionButton {
			ContextualButton(
				type: vm.contextAction,
				isInputVisible: coordinator.isContextualInputVisible,
				isLoading: vm.loading,
				phase: vm.uiPhase
			) {
				submitPrimaryAction(vm: vm, coordinator: coordinator)
			}
			.popoverTipIf(actionButtonTip, arrowEdge: .bottom, when: shouldShowTips)
		}
	}

	private func submitPrimaryAction(vm: GameViewModel, coordinator: AppCoordinator) {
		guard !vm.loading else { return }

		switch vm.contextAction {
		case .write:
			withAnimation(.snappy(duration: 0.3)) {
				coordinator.handleContextualAction(vm.contextAction) {
					vm.getResponse(for: vm.contextualInput)
				}
			}
		case .roll:
			if coordinator.isDicePromptVisible {
				vm.rollDice()
			} else {
				withAnimation(.snappy(duration: 0.3)) {
					coordinator.handleContextualAction(.roll) { false }
				}
			}
		}
	}

	private func configureTipsIfNeeded(shouldShowTips: Bool) {
		guard !tipsConfigured else { return }
		guard shouldShowTips else { return }
		try? Tips.configure([.displayFrequency(.immediate)])
		hasSeenGameTips = true
		tipsConfigured = true
	}

	private func presentInlineStatus(for phase: GameUIPhase) {
		guard let status = ResponseStatus(phase: phase) else {
			if phase == .composing || inlineResponseStatus?.isTemporary == false {
				dismissInlineStatus()
			}
			return
		}

		inlineStatusDismissTask?.cancel()
		withAnimation(.snappy(duration: 0.28)) {
			inlineResponseStatus = status
		}

		guard status.isTemporary else { return }

		inlineStatusDismissTask = Task {
			try? await Task.sleep(for: .seconds(3))
			guard !Task.isCancelled else { return }

			await MainActor.run {
				guard inlineResponseStatus?.id == status.id else { return }
				withAnimation(.snappy(duration: 0.28)) {
					inlineResponseStatus = nil
				}
			}
		}
	}

	private func dismissInlineStatus() {
		inlineStatusDismissTask?.cancel()
		withAnimation(.snappy(duration: 0.22)) {
			inlineResponseStatus = nil
		}
	}
}

extension View {
	@ViewBuilder
	fileprivate func popoverTipIf<T: Tip>(_ tip: T, arrowEdge: Edge = .top, when condition: Bool)
		-> some View
	{
		if condition {
			self.popoverTip(tip, arrowEdge: arrowEdge)
		} else {
			self
		}
	}
}

#Preview {
	GameView()
		.environment(AppCoordinator())
}

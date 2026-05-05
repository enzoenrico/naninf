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
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var vm = GameViewModel()

	var body: some View {
		GameSessionView(
			vm: vm,
			coordinator: coordinator,
			showsTips: true,
			onNavigateBack: {
				TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
					coordinator.resetGamePresentation()
					coordinator.back()
				}
			}
		)
	}
}

struct GameSessionView: View {
	let vm: GameViewModel
	let coordinator: AppCoordinator
	let showsTips: Bool
	let onNavigateBack: (() -> Void)?
	let onCompletedPlayerAction: (() -> Void)?

	@State private var actionAreaTip = ActionAreaTip()
	@State private var imageSectionTip = ImageSectionTip()
	@State private var actionButtonTip = ActionButtonTip()
	@State private var statBarsTip = StatBarsTip()
	@State private var tipsConfigured = false
	@State private var inlineResponseStatus: ResponseStatus?
	@State private var inlineStatusDismissTask: Task<Void, Never>?
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@AppStorage("hasSeenGameTips") private var hasSeenGameTips = false

	init(
		vm: GameViewModel,
		coordinator: AppCoordinator,
		showsTips: Bool,
		onNavigateBack: (() -> Void)? = nil,
		onCompletedPlayerAction: (() -> Void)? = nil
	) {
		self.vm = vm
		self.coordinator = coordinator
		self.showsTips = showsTips
		self.onNavigateBack = onNavigateBack
		self.onCompletedPlayerAction = onCompletedPlayerAction
	}

	var body: some View {
		@Bindable var coordinator = coordinator

		let shouldShowTips = showsTips && !hasSeenGameTips

		AppLayout(
			background: .terminalGrid,
			contentPadding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
		) {
			VStack(spacing: 12) {
				GameHeader(
					onBack: onNavigateBack,
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
		}
		.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation), value: inlineResponseStatus?.id)
		.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation), value: coordinator.isDicePromptVisible)
		.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation), value: coordinator.isContextualInputVisible)
		.animation(TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation), value: coordinator.isImageCollapsed)
		.tipViewStyle(AsciiTipStyle())
		.task {
			vm.attachCoordinator(coordinator)
			vm.onCompletedPlayerAction = onCompletedPlayerAction
			presentInlineStatus(for: vm.uiPhase)
			configureTipsIfNeeded(shouldShowTips: shouldShowTips)
		}
		.onChange(of: vm.uiPhase) { _, newPhase in
			presentInlineStatus(for: newPhase)
		}
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
				coordinator.toggleImage(reduceMotion: reduceMotion)
			}
			.terminalPanelTransition(edge: .top)
		} else {
			VisionPanel(
				isCollapsed: coordinator.isImageCollapsed,
				isLoading: vm.loading,
				phase: vm.uiPhase
			)
			.popoverTipIf(imageSectionTip, arrowEdge: .top, when: shouldShowTips)
			.terminalPanelTransition(edge: .top)
			.onTapGesture {
				coordinator.toggleImage(reduceMotion: reduceMotion)
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
				.terminalTextTransition(edge: .top)
			}

			TypeWriterView(vm.narrativeText) {
				vm.markNarrativeFinished()
				coordinator.handleTypewriterCompletion(reduceMotion: reduceMotion)
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
				.terminalPanelTransition(edge: .bottom)
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
			.terminalPanelTransition(edge: .bottom)
		}
	}

	private func submitPrimaryAction(vm: GameViewModel, coordinator: AppCoordinator) {
		guard !vm.loading else { return }

		switch vm.contextAction {
		case .write:
			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
				coordinator.handleContextualAction(vm.contextAction) {
					vm.getResponse(for: vm.contextualInput)
				}
			}
		case .roll:
			if coordinator.isDicePromptVisible {
				vm.rollDice(reduceMotion: reduceMotion)
			} else {
				TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
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
		TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
			inlineResponseStatus = status
		}

		guard status.isTemporary else { return }

		inlineStatusDismissTask = Task {
			try? await Task.sleep(for: .seconds(3))
			guard !Task.isCancelled else { return }

			await MainActor.run {
				guard inlineResponseStatus?.id == status.id else { return }
				TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
					inlineResponseStatus = nil
				}
			}
		}
	}

	private func dismissInlineStatus() {
		inlineStatusDismissTask?.cancel()
		TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.textAnimation) {
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

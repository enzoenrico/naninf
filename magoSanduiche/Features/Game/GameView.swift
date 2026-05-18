//
//  GameView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftData
import SwiftUI
import TipKit

struct GameView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Environment(\.modelContext) private var modelContext
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var vm = GameViewModel()

	var body: some View {
		GameSessionView(
			vm: vm,
			coordinator: coordinator,
			showsTips: true,
			onNavigateBack: {
				AppAnalytics.capture("game_back_tapped")
				vm.saveSnapshot(modelContext: modelContext)
				TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
					coordinator.resetGamePresentation()
					coordinator.back()
				}
			}
		)
		.onAppear {
			vm.modelContext = modelContext
			if let runID = coordinator.consumePendingResumeRunID() {
				vm.restore(runID: runID, modelContext: modelContext)
				coordinator.applyResumePresentationState()
			}
		}
		.onDisappear {
			vm.saveSnapshot(modelContext: modelContext)
		}
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
	@FocusState private var isContextualInputFocused: Bool
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@AppStorage("hasSeenGameTips") private var hasSeenGameTips = false

	/// Dice strip + bordered action panel + primary contextual button (worst-case session chrome).
	private static let gameActionColumnMinHeight: CGFloat = 220

	#if DEBUG
		@State private var showAIToolsDebug = false
	#endif

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
			// Session screen runs tighter than the document/hub default so the
			// scanline backdrop and bordered panels fill more of the viewport.
			contentPadding: EdgeInsets(
				top: Spacing.layoutTop,
				leading: Spacing.layoutTop,
				bottom: Spacing.layoutTop,
				trailing: Spacing.layoutTop
			)
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
				.dismissContextualInputOnTap(when: coordinator.isContextualInputVisible) {
					dismissContextualInputIfActive()
				}
				.popoverTipIf(statBarsTip, arrowEdge: .bottom, when: shouldShowTips)
				.zIndex(2)

				VStack(spacing: 12) {
					if coordinator.isImageCollapsed {
						sceneImage(coordinator: coordinator, vm: vm, shouldShowTips: shouldShowTips)
							.fixedSize(horizontal: false, vertical: true)
					} else {
						sceneImage(coordinator: coordinator, vm: vm, shouldShowTips: shouldShowTips)
							// .frame(maxHeight: .infinity, alignment: .top)
              .frame(alignment: .top)
							.layoutPriority(1)
					}

					VStack(spacing: 12) {
						actionPanel(coordinator: coordinator, vm: vm, shouldShowTips: shouldShowTips)
						actionButton(coordinator: coordinator, vm: vm, shouldShowTips: shouldShowTips)
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
					.layoutPriority(coordinator.isImageCollapsed ? 1 : 0)
					.frame(minHeight: Self.gameActionColumnMinHeight)
				}
				.frame(maxHeight: .infinity)
			}
			.frame(maxHeight: .infinity)
		}
		.animation(
			TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation), value: inlineResponseStatus?.id
		)
		.animation(
			TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
			value: coordinator.isDicePromptVisible
		)
		.animation(
			TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation),
			value: coordinator.isContextualInputVisible
		)
		.animation(
			TerminalMotion.animation(reduceMotion, TerminalMotion.panelAnimation), value: coordinator.isImageCollapsed
		)
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
		.onChange(of: coordinator.isContextualInputVisible) { _, isVisible in
			isContextualInputFocused = isVisible
		}
		#if DEBUG
			.sheet(isPresented: $showAIToolsDebug) {
				NavigationStack {
					AIToolsDebugView { effects in
						vm.applyToolEffectsFromDebug(effects)
					}
				}
				.presentationDetents([.fraction(0.25), .medium])
			}
		#endif
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
				handleVisionTap()
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
			.accessibilityAddTraits(.isButton)
			.onTapGesture {
				handleVisionTap()
			}
		}
	}

	private func actionPanel(
		coordinator: AppCoordinator,
		vm: GameViewModel,
		shouldShowTips: Bool
	) -> some View {
		ActionStack(title: vm.uiPhase.actionTitle) {
			terminalPanel(coordinator: coordinator, vm: vm)
		}
		.popoverTipIf(actionAreaTip, arrowEdge: .top, when: shouldShowTips)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private func terminalPanel(coordinator: AppCoordinator, vm: GameViewModel) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			#if DEBUG
				HStack {
					Spacer(minLength: 0)
					Button {
						showAIToolsDebug = true
					} label: {
						Text("nan_debug_ai_tools_chat_entry")
							.font(.monocraft(relativeTo: .caption2, weight: .semibold))
							.foregroundStyle(Color.terminalWarning)
					}
					.buttonStyle(.plain)
					.accessibilityHint(String(localized: "nan_debug_ai_tools_chat_entry_a11y"))
				}
			#endif

			if let inlineResponseStatus {
				InlineResponseStatusRow(status: inlineResponseStatus) {
					dismissInlineStatus()
				}
				.dismissContextualInputOnTap(when: coordinator.isContextualInputVisible) {
					dismissContextualInputIfActive()
				}
				.terminalTextTransition(edge: .top)
			}

			terminalTranscript(vm: vm, coordinator: coordinator)
				.layoutPriority(1)

			if coordinator.isContextualInputVisible {
				if vm.contextAction == .write, !vm.suggestedOptions.isEmpty {
					SuggestedOptionsList(
						options: vm.suggestedOptions,
						isDisabled: vm.loading,
						onSelect: { choice in
							submitSuggestedAction(choice, vm: vm, coordinator: coordinator)
						}
					)
					.terminalPanelTransition(edge: .bottom)
				}

				InputBox(
					with: Binding(
						get: { vm.contextualInput },
						set: { vm.contextualInput = $0 }
					),
					isFocused: $isContextualInputFocused,
					isDisabled: vm.loading,
					invalidAttempts: vm.invalidInputAttempts
				) {
					submitPrimaryAction(vm: vm, coordinator: coordinator)
				}
				.terminalPanelTransition(edge: .bottom)
			}
		}
		.padding(12)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	}

	@ViewBuilder
	private func terminalTranscript(vm: GameViewModel, coordinator: AppCoordinator) -> some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				ForEach(vm.terminalEntries) { entry in
					terminalEntryView(entry: entry, vm: vm, coordinator: coordinator)
				}

				if coordinator.isDicePromptVisible {
					DicePromptView(
						diceValue: vm.diceValue,
						revealStage: vm.diceRevealStage,
						resultText: vm.diceResultText,
						showRollingFlavor:
							vm.loading && vm.uiPhase == .rollingDice && vm.diceRevealStage != .bamReveal
					)
					.drawBorder("nan_dice_prompt", color: .accent, lineWidth: 2, animate: true, glowPreset: .chrome)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.contentShape(Rectangle())
			.dismissContextualInputOnTap(when: coordinator.isContextualInputVisible) {
				dismissContextualInputIfActive()
			}
		}
		.scrollDismissesKeyboard(.immediately)
		.defaultScrollAnchor(.bottom)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.clipped()
		.padding(.horizontal, 4)
	}

	@ViewBuilder
	private func terminalEntryView(entry: TerminalEntry, vm: GameViewModel, coordinator: AppCoordinator) -> some View {
		let isLatest = entry.id == vm.terminalEntries.last?.id
		let useTypewriter =
			!vm.suppressTerminalAnimations
			&& isLatest
			&& (entry.kind == .dungeonMaster || entry.kind == .system)

		if useTypewriter {
			TypeWriterView(entry.renderedText, embedsScrollView: false) {
				vm.markNarrativeFinished()
				if !coordinator.hasCompletedInitialText {
					coordinator.handleTypewriterCompletion(reduceMotion: reduceMotion)
				}
			}
			.simultaneousGesture(
				TapGesture().onEnded {
					guard coordinator.isContextualInputVisible else { return }
					dismissContextualInputIfActive()
				}
			)
		} else {
			Text(entry.renderedText)
				.font(.monocraft())
				.foregroundStyle(Color.accent)
				.frame(maxWidth: .infinity, alignment: .leading)
				.dismissContextualInputOnTap(when: coordinator.isContextualInputVisible) {
					dismissContextualInputIfActive()
				}
		}
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
				phase: vm.uiPhase,
				confirmDiceOutcome: vm.pendingDiceRoll != nil
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
				if vm.pendingDiceRoll != nil {
					TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
						vm.commitDiceRollOutcome()
					}
				} else {
					vm.rollDice(reduceMotion: reduceMotion)
				}
			} else {
				TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
					coordinator.handleContextualAction(.roll) { false }
				}
			}
		}
	}

	private func submitSuggestedAction(_ choice: String, vm: GameViewModel, coordinator: AppCoordinator) {
		guard !vm.loading else { return }
		guard vm.contextAction == .write else { return }

		TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
			coordinator.handleContextualAction(vm.contextAction) {
				vm.getResponse(for: choice)
			}
		}
	}

	private func configureTipsIfNeeded(shouldShowTips: Bool) {
		guard !tipsConfigured else { return }
		guard shouldShowTips else { return }
		try? Tips.configure([.displayFrequency(.immediate)])
		hasSeenGameTips = true
		tipsConfigured = true
		AppAnalytics.capture("game_tips_shown")
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

	private func handleVisionTap() {
		if coordinator.isContextualInputVisible {
			dismissContextualInputIfActive()
		}
		coordinator.toggleImage(reduceMotion: reduceMotion)
	}

	private func dismissContextualInputIfActive() {
		guard coordinator.isContextualInputVisible else { return }
		isContextualInputFocused = false
		coordinator.dismissContextualInput(reduceMotion: reduceMotion)
	}
}

private extension View {
	@ViewBuilder
	func dismissContextualInputOnTap(when isActive: Bool, perform dismiss: @escaping () -> Void) -> some View {
		if isActive {
			self
				.contentShape(Rectangle())
				.onTapGesture(perform: dismiss)
		} else {
			self
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

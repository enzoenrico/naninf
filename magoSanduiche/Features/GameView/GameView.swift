//
//  ContentView.swift
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
	@AppStorage("hasSeenGameTips") private var hasSeenGameTips = false

	@State var vm = GameViewModel()

	var body: some View {
		@Bindable var coordinator = coordinator

		let shouldShowTips = !hasSeenGameTips

		let sceneImage = VStack {
			Image(.bread)  // change to rendered
				.resizable()
				.interpolation(.none)
				.interpolation(.none)
				.scaledToFill()
				.padding()
				.frame(height: coordinator.isImageCollapsed ? 0 : .infinity)
				.foregroundStyle(.accent)
		}
		.clipped()
		.drawBorder()

		VStack {
			GameHeader()
				.popoverTipIf(statBarsTip, arrowEdge: .bottom, when: shouldShowTips)
				.frame(height: 50)
				.zIndex(2)

			VStack {
				if coordinator.isImageCollapsed {
					Spacer(minLength: 0)
				} else {
					sceneImage
						.popoverTipIf(imageSectionTip, arrowEdge: .top, when: shouldShowTips)
				}

				ActionStack {
					TypeWriterView(
						// Introduction.intro
						"bunda liquida"
					) {
						coordinator.handleTypewriterCompletion()
					}
					.padding()
					if coordinator.isContextualInputVisible {
						InputBox(with: $vm.contextualInput)
					}
				}
				.popoverTipIf(actionAreaTip, arrowEdge: .top, when: shouldShowTips)
				.offset(y: coordinator.isImageCollapsed ? 0 : -20)
				.frame(width: .infinity)
				.onTapGesture {
					withAnimation(.easeInOut) {
						coordinator.toggleImageVisibility()
					}
				}
				.padding(.horizontal, coordinator.isImageCollapsed ? 0 : 8)
				.padding(.vertical, coordinator.isImageCollapsed ? 8 : 0)

				// Spacer()

				if coordinator.showActionButton {
					ContextualButton(type: .write, isInputVisible: coordinator.isContextualInputVisible) {
						withAnimation(.easeInOut) {
							coordinator.handleContextualAction(.write) {
								//vm.submitGameAction(coordinator.contextualInput)
                                vm.getResponse(for: vm.contextualInput)
							}
						}
						// vm.getResponse()
					}
					.popoverTipIf(actionButtonTip, arrowEdge: .bottom, when: shouldShowTips)
					.padding(.bottom, 8)
				}
			}
		}
		.navigationBarBackButtonHidden()
		.ignoresSafeArea()
		.padding()
		.background(Color.background)
		.tipViewStyle(AsciiTipStyle())
		.task {
			guard !tipsConfigured else { return }
			guard shouldShowTips else { return }
			try? Tips.configure([.displayFrequency(.immediate)])
			hasSeenGameTips = true
			tipsConfigured = true
		}
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

private extension View {
	@ViewBuilder
	func popoverTipIf<T: Tip>(_ tip: T, arrowEdge: Edge = .top, when condition: Bool) -> some View {
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

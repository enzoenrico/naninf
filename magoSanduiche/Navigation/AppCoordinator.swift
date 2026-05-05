//
//  AppCoordinator.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

@Observable
final class AppCoordinator {
	var path = NavigationPath()
	var isDicePromptVisible = false
	var hasCompletedInitialText = false
	var showActionButton = false

	private var isUpdatingPresentationState = false

	var isImageCollapsed = true {
		didSet {
			guard !isUpdatingPresentationState else { return }
			guard !isImageCollapsed, isContextualInputVisible else { return }
			updatePresentationState {
				isContextualInputVisible = false
			}
		}
	}

	var isContextualInputVisible = false {
		didSet {
			guard !isUpdatingPresentationState else { return }
			guard isContextualInputVisible, !isImageCollapsed else { return }
			updatePresentationState {
				isImageCollapsed = true
			}
		}
	}

	func handleContextualAction(_ action: GameAction, onSubmit: () -> Bool) {
		switch action {
		case .write:
			handleWriteAction(onSubmit: onSubmit)
		case .roll:
			showDicePrompt()
		}
	}

	func finishDicePrompt() {
		updatePresentationState {
			isContextualInputVisible = false
			isDicePromptVisible = false
			isImageCollapsed = true
			showActionButton = true
		}
	}

	func prepareForTextInput() {
		updatePresentationState {
			isContextualInputVisible = true
			isDicePromptVisible = false
			isImageCollapsed = true
		}
	}

	func showDicePrompt() {
		updatePresentationState {
			isContextualInputVisible = false
			isDicePromptVisible = true
			isImageCollapsed = false
		}
	}

	func resetActionPresentation() {
		updatePresentationState {
			isContextualInputVisible = false
			isDicePromptVisible = false
			isImageCollapsed = true
		}
	}

	func resetGamePresentation() {
		updatePresentationState {
			isContextualInputVisible = false
			isDicePromptVisible = false
			isImageCollapsed = true
			hasCompletedInitialText = false
			showActionButton = false
		}
	}

	func handleTypewriterCompletion(reduceMotion: Bool = false) {
		TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
			hasCompletedInitialText = true
			isImageCollapsed = false
			showActionButton = true
		}
	}

	func toggleImage(reduceMotion: Bool = false) {
		guard hasCompletedInitialText else { return }
		TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
			isImageCollapsed.toggle()
		}
	}

	func navigate(to route: AppRoute) {
		path.append(route)
	}

	func back() {
		guard !path.isEmpty else { return }
		path.removeLast()
	}

	func popToRoot() {
		path.removeLast(path.count)
	}

	private func handleWriteAction(onSubmit: () -> Bool) {
		if isContextualInputVisible {
			if onSubmit() {
				resetActionPresentation()
			}
		} else {
			prepareForTextInput()
		}
	}

	private func updatePresentationState(_ update: () -> Void) {
		isUpdatingPresentationState = true
		update()
		isUpdatingPresentationState = false
	}
}

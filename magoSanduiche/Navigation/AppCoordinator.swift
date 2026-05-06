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
		AppAnalytics.capture("game_contextual_action_tapped", properties: [
			"action": String(describing: action),
			"is_contextual_input_visible": isContextualInputVisible,
			"is_dice_prompt_visible": isDicePromptVisible
		])

		switch action {
		case .write:
			handleWriteAction(onSubmit: onSubmit)
		case .roll:
			showDicePrompt()
		}
	}

	func finishDicePrompt() {
		AppAnalytics.capture("game_dice_prompt_finished")
		updatePresentationState {
			isContextualInputVisible = false
			isDicePromptVisible = false
			isImageCollapsed = true
			showActionButton = true
		}
	}

	func prepareForTextInput() {
		AppAnalytics.capture("game_text_input_opened")
		updatePresentationState {
			isContextualInputVisible = true
			isDicePromptVisible = false
			isImageCollapsed = true
		}
	}

	func showDicePrompt() {
		AppAnalytics.capture("game_dice_prompt_opened")
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
		AppAnalytics.capture("game_presentation_reset")
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
			AppAnalytics.capture("game_image_toggled", properties: [
				"is_collapsed": isImageCollapsed
			])
		}
	}

	func navigate(to route: AppRoute) {
		AppAnalytics.capture("navigation_route_opened", properties: [
			"route": String(describing: route),
			"path_depth_before": path.count
		])
		path.append(route)
	}

	func back() {
		guard !path.isEmpty else { return }
		AppAnalytics.capture("navigation_back_tapped", properties: [
			"path_depth_before": path.count
		])
		path.removeLast()
	}

	func popToRoot() {
		AppAnalytics.capture("navigation_pop_to_root", properties: [
			"path_depth_before": path.count
		])
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

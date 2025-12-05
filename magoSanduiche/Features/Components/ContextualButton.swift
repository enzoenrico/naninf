//
//  ContextualButton.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

import SwiftUI

enum ContextualActions {
	case write
	case roll

	var buttonValue: String {
		switch self {
		case .write:
			"What's your next action?"
		case .roll:
			"Roll the dice"
		}
	}
	var buttonImage: Icons {
		switch self {
		case .write:
			.ink
		case .roll:
			.dice
		}
	}
}

struct ContextualButton: View {
	var action: ContextualActions
	private func callContextualAction() {
		switch self.action {
		// TODO: implement the action switch
		default:
			print("hello world")
		}
	}

	var body: some View {
		Button(
			action: { callContextualAction() },
			label: {
                Label(action.buttonValue, image: action.buttonImage.rawValue)
					.foregroundStyle(Color.accent)
					.padding(8)
					.frame(maxWidth: .infinity)
					.labelStyle(.tintedIcon(color: .accent))
			}
		)
		.drawBorder()
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

struct TintedIconLabelStyle: LabelStyle {
	var iconTintColor: Color

	func makeBody(configuration: Configuration) -> some View {
		HStack {
			configuration.icon
				.foregroundStyle(iconTintColor)
			configuration.title
		}
	}
}

extension LabelStyle where Self == TintedIconLabelStyle {
	static func tintedIcon(color: Color) -> TintedIconLabelStyle {
		TintedIconLabelStyle(iconTintColor: color)
	}
}

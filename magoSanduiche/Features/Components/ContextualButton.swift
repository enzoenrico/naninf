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

	func buttonValue(isInputVisible: Bool) -> String {
		switch self {
		case .write:
			isInputVisible ? "Send your action" : "What's your next action?"
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
	var type: ContextualActions
	var isInputVisible: Bool = false
	var action: () -> Void

	var body: some View {
		Button(
			action: action,
			label: {
				Label(type.buttonValue(isInputVisible: isInputVisible), image: type.buttonImage.rawValue)
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

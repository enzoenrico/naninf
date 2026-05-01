//
//  GameTips.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 10/12/25.
//

import SwiftUI
import TipKit

struct ActionAreaTip: Tip {
	var title: Text { Text("Your actions") }
	var message: Text? { Text("Everything that happens in the world is shown here") }
	var image: Image? { Image(systemName: "text.justify.left") }
}

struct ImageSectionTip: Tip {
	var title: Text { Text("See the world") }
	var message: Text? { Text("Images are generated to show important characters, actions and events") }
	var image: Image? { Image(systemName: "photo.on.rectangle") }
}

struct ActionButtonTip: Tip {
	var title: Text { Text("Take your turn") }
	var message: Text? { Text("Use the action button whenever you can make a move.") }
	var image: Image? { Image(systemName: "wand.and.stars") }
}

struct StatBarsTip: Tip {
	var title: Text { Text("Health and mana") }
	var message: Text? { Text("Keep track of your health and mana, so the dungeon does not get the best of you") }
	var image: Image? { Image(systemName: "heart.text.square") }
}

struct AsciiTipStyle: TipViewStyle {
	func makeBody(configuration: Configuration) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(spacing: 8) {
				if let image = configuration.image {
					image.foregroundStyle(.accent)
				}
				configuration.title
					.foregroundStyle(.accent)
					.font(.headline)
			}

			if let message = configuration.message {
				message
					.font(.footnote)
					.foregroundStyle(.accent)
			}
		}
		.padding(10)
		.background(Color.background)
	}
}

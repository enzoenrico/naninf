//
//  GameTips.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 10/12/25.
//

import SwiftUI
import TipKit

struct ActionAreaTip: Tip {
	var title: Text { Text("nan_tip_action_title") }
	var message: Text? { Text("nan_tip_action_message") }
	var image: Image? { Image(systemName: "text.justify.left") }
}

struct ImageSectionTip: Tip {
	var title: Text { Text("nan_tip_image_title") }
	var message: Text? { Text("nan_tip_image_message") }
	var image: Image? { Image(systemName: "photo.on.rectangle") }
}

struct ActionButtonTip: Tip {
	var title: Text { Text("nan_tip_button_title") }
	var message: Text? { Text("nan_tip_button_message") }
	var image: Image? { Image(systemName: "wand.and.stars") }
}

struct StatBarsTip: Tip {
	var title: Text { Text("nan_tip_stats_title") }
	var message: Text? { Text("nan_tip_stats_message") }
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
					.font(.monocraft(relativeTo: .headline, weight: .semibold))
			}

			if let message = configuration.message {
				message
					.font(.monocraft(relativeTo: .footnote))
					.foregroundStyle(.accent)
			}
		}
		.padding(10)
		.background(Color.background)
	}
}

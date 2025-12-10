//
//  GameTips.swift
//  magoSanduiche
//
//  Created by GitHub Copilot on 10/12/25.
//

import SwiftUI
import TipKit

struct ActionAreaTip: Tip {
    var title: Text { Text("Action log") }
    var message: Text? { Text("AI feedback, dice rolls, and events land here.") }
    var image: Image? { Image(systemName: "text.justify.left") }
}

struct ImageSectionTip: Tip {
    var title: Text { Text("Scene snapshots") }
    var message: Text? { Text("Open the image view to see a visual of recent actions.") }
    var image: Image? { Image(systemName: "photo.on.rectangle") }
}

struct ActionButtonTip: Tip {
    var title: Text { Text("Take your turn") }
    var message: Text? { Text("Use the action button whenever you can make a move.") }
    var image: Image? { Image(systemName: "wand.and.stars") }
}

struct StatBarsTip: Tip {
    var title: Text { Text("Track HP and MP") }
    var message: Text? { Text("These bars show your current health and mana.") }
    var image: Image? { Image(systemName: "heart.text.square") }
}

struct AsciiTipStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let image = configuration.image {
                    image
                        .foregroundStyle(.accent)
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

            //configuration.actions
        }
        .padding(10)
        .background(Color.background)
        .drawBorder("> Tutorial")
    }
}

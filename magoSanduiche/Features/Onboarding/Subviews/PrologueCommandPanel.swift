//
//  PrologueCommandPanel.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI
import Foundation

struct PrologueCommandPanel: View {
	let command: String
	let isFinalCommand: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(String(localized: "nan_prologue_terminal_title"))
				.font(.monocraft(relativeTo: .caption, weight: .semibold))
				.foregroundStyle(isFinalCommand ? Color.terminalWarning : Color.accent)

			HStack(alignment: .firstTextBaseline, spacing: 8) {
				Text("$")
					.font(.monocraft(relativeTo: .headline, weight: .bold))
					.foregroundStyle(Color.accent)
				Text(command)
					.font(.monocraft(relativeTo: .callout))
					.foregroundStyle(Color.accent)
				Spacer(minLength: 0)
				BlinkingCursor()
			}

			Text(
				isFinalCommand
					? String(localized: "nan_prologue_footer_final")
					: String(localized: "nan_prologue_footer_learning")
			)
				.font(.monocraft(relativeTo: .caption))
				.foregroundStyle(Color.terminalMutedText)
		}
		.padding(12)
		.background(Color.terminalSurface)
		.drawBorder(
			nil,
			color: isFinalCommand ? Color.terminalWarning : Color.accent,
			lineWidth: isFinalCommand ? 2 : 1
		)
		.accessibilityElement(children: .combine)
	}
}

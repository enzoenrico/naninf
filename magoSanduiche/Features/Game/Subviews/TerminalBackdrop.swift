//
//  TerminalBackdrop.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct TerminalBackdrop: View {
	var body: some View {
		ZStack {
			Color.background

			LinearGradient(
				colors: [
					Color.accent.opacity(0.12),
					Color.clear,
					Color.terminalMana.opacity(0.08),
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)

			VStack(spacing: 7) {
				ForEach(0..<80, id: \.self) { _ in
					Rectangle()
						.fill(Color.terminalGrid)
						.frame(height: 1)
				}
			}
			.opacity(0.28)
		}
	}
}

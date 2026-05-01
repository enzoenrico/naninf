//
//  BlinkingCursor.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct BlinkingCursor: View {
	@State private var isVisible = true

	var body: some View {
		Text("▌")
			.font(.monocraft(relativeTo: .callout, weight: .bold))
			.foregroundStyle(Color.accent)
			.opacity(isVisible ? 1 : 0.2)
			.task {
				while !Task.isCancelled {
					try? await Task.sleep(for: .milliseconds(520))
					isVisible.toggle()
				}
			}
	}
}

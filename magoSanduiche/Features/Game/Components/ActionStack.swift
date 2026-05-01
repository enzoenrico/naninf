//
//  ActionStack.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import SwiftUI

struct ActionStack<Content: View>: View {
	var title: String
	@ViewBuilder var content: () -> Content

	init(title: String = "> Actions", @ViewBuilder content: @escaping () -> Content) {
		self.title = title
		self.content = content
	}

	var body: some View {
		VStack(alignment: .center, spacing: 10) {
			content()
				.drawBorder(title, lineWidth: 2)
				.frame(width: .infinity, height: .infinity)
		}
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

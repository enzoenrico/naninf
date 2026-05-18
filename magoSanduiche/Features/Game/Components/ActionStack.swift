//
//  ActionStack.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import SwiftUI
import Foundation

struct ActionStack<Content: View>: View {
	var title: String
	@ViewBuilder var content: () -> Content

	init(title: String = String(localized: "nan_action_stack_title"), @ViewBuilder content: @escaping () -> Content) {
		self.title = title
		self.content = content
	}

	var body: some View {
		VStack(alignment: .center, spacing: 10) {
			content()
				.drawBorder(title, lineWidth: 2)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

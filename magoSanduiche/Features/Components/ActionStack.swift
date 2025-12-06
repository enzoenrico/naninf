//
//  ActionStack.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import Foundation
import SwiftUI

// stack for the action modal
struct ActionStack<Content: View>: View {
	@ViewBuilder var content: () -> Content

	var body: some View {
		VStack(alignment: .center, spacing: 10) {
			content()
				.drawBorder("> Actions")
				.frame(width: .infinity, height: .infinity)
		}
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

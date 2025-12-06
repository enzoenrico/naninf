//
//  GameHeader.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 05/12/25.
//

import SwiftUI

struct GameHeader: View {
	var body: some View {
		HStack(alignment: .center) {
			VStack {
				Image(.bread)
					.resizable()
					.padding()
					.scaledToFill()
					.foregroundStyle(.accent)
			}
			.frame(width: 75)
			.drawBorder()
			.padding(8)

			VStack(alignment: .leading) {
				AsciiProgressBar(.health, progress: 10)  // add viewmodel values
				AsciiProgressBar(.mana, progress: 60)  // add viewmodel values
			}
			.frame(height: 75)
		}
		.drawBorder()
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

//
//  HomeHeroBanner.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI

struct HomeHeroBanner: View {
	let tagline: String

	var body: some View {
		VStack(alignment: .leading, spacing: Spacing.sm) {
			AsciiMediaView(catalogVideoNamed: "mageOpening")
				.asciiScaleMode(.fill)
				.asciiColumns(228)
				.asciiFontSize(8)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.layoutPriority(1)

			HStack(alignment: .firstTextBaseline, spacing: 0) {
				TypeWriterView(tagline, embedsScrollView: false, lineLimit: 2)
					.fixedSize(horizontal: false, vertical: true)
			}
			.padding(Spacing.xl)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.drawBorder(String(localized: "nan_home_hero_border_title"), color: .accent, lineWidth: 1, animate: true)
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

#Preview {
	HomeHeroBanner(tagline: String(localized: "nan_home_tagline"))
		.padding()
		.background(Color.background)
}

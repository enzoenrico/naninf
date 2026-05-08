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
		VStack(alignment: .leading, spacing: 12) {
			//VStack(alignment: .leading, spacing: 4) {
			//	//CRTRevealText(
			//	//	text: "Welcome to NanInf",
			//	//	font: .monocraft(relativeTo: .title2, weight: .bold),
			//	//	color: .accent,
			//	//	delay: .milliseconds(60)
			//	//)
			//	//.shadow(color: Color.accent.opacity(0.55), radius: 8)
			//}
			//.padding(14)

			//			CRTRevealText(
			//				text: HomeAsciiArt.crest,
			//				font: .monocraft(size: 12),
			//				color: .accent,
			//				delay: .milliseconds(140),
			//				charInterval: .milliseconds(4),
			//				scrambleSwaps: 0
			//			)
			AsciiMediaView(catalogVideoNamed: "mageOpening")
				.asciiScaleMode(.fill)
				.asciiColumns(228)
				.asciiFontSize(8)
				.frame(maxWidth: .infinity)
				.padding(.vertical)

			HStack(alignment: .firstTextBaseline, spacing: 0) {
				CRTRevealText(
					text: tagline,
					font: .monocraft(relativeTo: .callout, weight: .semibold),
					color: .terminalWarning,
					lineLimit: 2,
					delay: .milliseconds(220),
					showsCursorWhileTyping: true
				)
				.frame(maxHeight: 44, alignment: .leading)
			}
			.padding(.horizontal, 4)
			.padding(14)
		}
		.frame(maxWidth: .infinity)
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

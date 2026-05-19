//
//  HomeHeroBanner.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import SwiftUI

struct HomeHeroBanner: View {
	let tagline: String
	var onOracleTap: (() -> Void)? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: Spacing.sm) {
			Button {
				onOracleTap?()
			} label: {
				AsciiMediaView(catalogVideoNamed: "mageOpening")
					.asciiScaleMode(.fill)
					.asciiColumns(228)
					.asciiFontSize(8)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			.buttonStyle(.plain)
			.disabled(onOracleTap == nil)
			.accessibilityLabel(String(localized: "nan_oracle_a11y_label"))
			.accessibilityHint(
				onOracleTap == nil
					? ""
					: String(localized: "nan_oracle_a11y_hint")
			)
			.layoutPriority(1)

			HStack(alignment: .firstTextBaseline, spacing: 0) {
				TypeWriterView(tagline, embedsScrollView: false, lineLimit: 2)
					.fixedSize(horizontal: false, vertical: true)
					.id(tagline)
			}
			.padding(Spacing.xl)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.drawBorder(nil, color: .accent, lineWidth: 1, animate: true)
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

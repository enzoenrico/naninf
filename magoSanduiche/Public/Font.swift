//
//  Font.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 10/12/25.
//

import SwiftUI

#if canImport(UIKit)
	import UIKit
#endif

extension Font {
	static func monocraft(relativeTo style: TextStyle = .body, weight: Font.Weight = .regular) -> Font {
		let pointSize: CGFloat
		#if canImport(UIKit)
			pointSize = UIFont.preferredFont(forTextStyle: style.uiKitStyle).pointSize
		#else
			pointSize = fallbackPointSize(for: style)
		#endif

		return Font.custom("Monocraft", size: pointSize, relativeTo: style)
			.weight(weight)
	}
}

private extension Font.TextStyle {
	#if canImport(UIKit)
		var uiKitStyle: UIFont.TextStyle {
			switch self {
			case .largeTitle: .largeTitle
			case .title: .title1
			case .title2: .title2
			case .title3: .title3
			case .headline: .headline
			case .subheadline: .subheadline
			case .body: .body
			case .callout: .callout
			case .caption: .caption1
			case .caption2: .caption2
			case .footnote: .footnote
			@unknown default: .body
			}
		}
	#endif
}

private func fallbackPointSize(for style: Font.TextStyle) -> CGFloat {
	switch style {
	case .largeTitle: 34
	case .title: 28
	case .title2: 22
	case .title3: 20
	case .headline: 17
	case .subheadline: 15
	case .body: 17
	case .callout: 16
	case .caption: 12
	case .caption2: 11
	case .footnote: 13
	@unknown default: 17
	}
}

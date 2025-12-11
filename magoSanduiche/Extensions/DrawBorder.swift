//
//  GreenBorder.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import Foundation
import SwiftUI

extension View {
	func drawBorder(_ desc: String? = nil) -> some View {
		VStack {
			self
				.overlay(
					alignment: .center,
				) {
					GeometryReader { geo in
						ZStack {
							if let desc {
								Text(desc)
									.font(.monocraft(relativeTo: .caption))
									.foregroundStyle(.accent)
									.padding(.horizontal, 4)
									.padding(.vertical, 0)
									.background(Color.background)
									.offset(x: -geo.size.width / 2.5, y: -geo.size.height / 2)
									.lineLimit(1)
									.zIndex(.greatestFiniteMagnitude)
							}
							RoundedRectangle(cornerRadius: 0)
								.stroke(.accent, lineWidth: 3)
								.foregroundStyle(.clear)
						}
					}
				}
		}
		.background(Color.background)
	}
}

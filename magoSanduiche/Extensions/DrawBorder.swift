//
//  GreenBorder.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import Foundation
import SwiftUI

extension View {
	public func drawBorder(_ desc: String? = nil) -> some View {
		VStack {
			self
				.overlay(
					alignment: .center,
				) {
					GeometryReader { geo in
						ZStack {
							if let desc {
								Text(desc)
									.font(.caption2)
									.foregroundStyle(.accent)
									.padding(.horizontal, 4)
                                    .padding(.vertical, 0)
									.background(Color.background)
									.offset(x: -geo.size.width / 3, y: -geo.size.height / 2)
									.lineLimit(1)
									.zIndex(.greatestFiniteMagnitude)
							}
							RoundedRectangle(cornerRadius: 8)
								.stroke(.accent, lineWidth: 3)
								.foregroundStyle(.clear)
						}
					}
				}
		}
		.background(Color.background)
	}
}

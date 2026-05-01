//
//  GreenBorder.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import Foundation
import SwiftUI

extension View {
	func drawBorder(
		_ desc: String? = nil,
		color: Color = .accent,
		lineWidth: CGFloat = 2
	) -> some View {
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
									.foregroundStyle(color)
									.padding(.horizontal, 4)
									.padding(.vertical, 0)
									.background(Color.background)
									.offset(x: -geo.size.width / 2.5, y: -geo.size.height / 2)
									.lineLimit(1)
									.zIndex(.greatestFiniteMagnitude)
							}
							RoundedRectangle(cornerRadius: 0)
								.stroke(color, lineWidth: lineWidth)
								.foregroundStyle(.clear)
						}
					}
				}
		}
		.background(Color.background)
	}
}

extension Color {
	static let terminalSurface = Color(red: 0.02, green: 0.05, blue: 0.10)
	static let terminalActiveSurface = Color(red: 0.03, green: 0.09, blue: 0.07)
	static let terminalGrid = Color.accent.opacity(0.18)
	static let terminalMutedText = Color(red: 0.43, green: 0.55, blue: 0.50)
	static let terminalDanger = Color(red: 0.96, green: 0.25, blue: 0.25)
	static let terminalMana = Color(red: 0.25, green: 0.78, blue: 1.00)
	static let terminalWarning = Color(red: 1.00, green: 0.75, blue: 0.24)
}

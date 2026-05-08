//
//  GreenBorder.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 04/12/25.
//

import SwiftUI

// MARK: - Border stroke with optional top gap (for title text)

private struct DrawBorderLabelFrameKey: PreferenceKey {
	static var defaultValue: [UUID: CGRect] = [:]
	static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
		value.merge(nextValue(), uniquingKeysWith: { _, new in new })
	}
}

/// Rectangular outline matching `Rectangle().stroke`; omits the top edge between `gapLeft` and `gapRight` when `hasTitle` and `topGap` are valid.
private struct RectBorderWithTopGapShape: Shape {
	var topGap: CGRect
	var hasTitle: Bool

	func path(in rect: CGRect) -> Path {
		guard hasTitle, topGap.width > 1, topGap.height > 1 else {
			return Rectangle().path(in: rect)
		}

		let horizontalPad: CGFloat = 3
		let gapLeft = max(rect.minX, topGap.minX - horizontalPad)
		let gapRight = min(rect.maxX, topGap.maxX + horizontalPad)
		guard gapLeft < gapRight - 0.5 else {
			return Rectangle().path(in: rect)
		}

		let minX = rect.minX
		let minY = rect.minY
		let maxX = rect.maxX
		let maxY = rect.maxY

		var p = Path()
		p.move(to: CGPoint(x: minX, y: minY))
		p.addLine(to: CGPoint(x: gapLeft, y: minY))
		p.move(to: CGPoint(x: gapRight, y: minY))
		p.addLine(to: CGPoint(x: maxX, y: minY))
		p.addLine(to: CGPoint(x: maxX, y: maxY))
		p.addLine(to: CGPoint(x: minX, y: maxY))
		p.addLine(to: CGPoint(x: minX, y: minY))
		return p
	}
}

// MARK: - Public API

extension View {
	/// Outlined rectangle border with an optional title gap.
	/// - Parameter animate: When `true`, the border reads
	///   `\.crtRevealPhase` from the environment and animates its stroke via
	///   `Shape.trim(from:to:)`, producing a CRT-style pen-trace. Defaults to
	///   `false` so every existing call site renders unchanged.
	func drawBorder(
		_ desc: String? = nil,
		color: Color = .accent,
		lineWidth: CGFloat = 2,
		animate: Bool = false
	) -> some View {
		DrawBorderModifierContent(
			content: self,
			desc: desc,
			color: color,
			lineWidth: lineWidth,
			animate: animate
		)
	}
}

private struct DrawBorderModifierContent<Content: View>: View {
	@Environment(\.crtRevealBorderProgress) private var crtBorderProgress
	private let instanceId = UUID()
	let content: Content
	let desc: String?
	let color: Color
	let lineWidth: CGFloat
	let animate: Bool

	@State private var labelFrame: CGRect = .zero

	var body: some View {
		content
			.overlay(alignment: .center) {
				GeometryReader { geo in
					ZStack {
						RectBorderWithTopGapShape(
							topGap: labelFrame,
							hasTitle: desc != nil
						)
						.trim(from: 0, to: trimEnd)
						.stroke(color, lineWidth: lineWidth)

						if let desc {
							Text(desc)
								.font(.monocraft(relativeTo: .caption))
								.foregroundStyle(color)
								.padding(.horizontal, 4)
								.padding(.vertical, 0)
								.lineLimit(1)
								.opacity(labelOpacity)
								.background(
									GeometryReader { g in
										Color.clear.preference(
											key: DrawBorderLabelFrameKey.self,
											value: [instanceId: g.frame(in: .named("drawBorder"))]
										)
									}
								)
								.offset(x: -geo.size.width * 0.3, y: -geo.size.height / 2)
								.zIndex(1)
						}
					}
					.coordinateSpace(name: "drawBorder")
					.onPreferenceChange(DrawBorderLabelFrameKey.self) { dict in
						labelFrame = dict[instanceId] ?? .zero
					}
				}
			}
	}

	private var trimEnd: CGFloat {
		guard animate else { return 1 }
		return CGFloat(max(0, min(1, crtBorderProgress)))
	}

	// Fade the title alongside the trace; the label still occupies its frame
	// so the gap measurement stays stable through the animation.
	private var labelOpacity: Double {
		guard animate else { return 1 }
		return max(0, min(1, crtBorderProgress))
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

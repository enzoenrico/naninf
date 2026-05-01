//
//  InputBox.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 10/12/25.
//

import SwiftUI

struct InputBox: View {
	var textbinding: Binding<String>
	var isDisabled: Bool
	var invalidAttempts: Int
	var onSubmit: () -> Void

	@FocusState private var isFocused: Bool
	@State private var shakeOffset: CGFloat = 0

	init(
		with bind: Binding<String>,
		isDisabled: Bool = false,
		invalidAttempts: Int = 0,
		onSubmit: @escaping () -> Void = {}
	) {
		self.textbinding = bind
		self.isDisabled = isDisabled
		self.invalidAttempts = invalidAttempts
		self.onSubmit = onSubmit
	}

	var body: some View {
		HStack(spacing: 8) {
			Text(">")
				.font(.monocraft(relativeTo: .headline, weight: .semibold))
				.foregroundStyle(isDisabled ? Color.terminalMutedText : Color.accent)

			TextField("Describe your next action", text: textbinding)
				.focused($isFocused)
				.font(.monocraft(relativeTo: .body))
				.foregroundStyle(Color.accent)
				.submitLabel(.send)
				.textInputAutocapitalization(.never)
				.disableAutocorrection(true)
				.disabled(isDisabled)
				.onSubmit(onSubmit)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 12)
		.background(isFocused ? Color.terminalActiveSurface : Color.terminalSurface)
		.drawBorder(
			isFocused ? "> Command" : nil,
			color: isDisabled ? Color.terminalMutedText : Color.accent,
			lineWidth: isFocused ? 2 : 1
		)
		.opacity(isDisabled ? 0.65 : 1)
		.offset(x: shakeOffset)
		.onAppear {
			guard !isDisabled else { return }
			isFocused = true
		}
		.onChange(of: invalidAttempts) { _, _ in
			withAnimation(.linear(duration: 0.06).repeatCount(5, autoreverses: true)) {
				shakeOffset = 6
			}
			Task {
				try? await Task.sleep(for: .milliseconds(340))
				shakeOffset = 0
			}
		}
		.accessibilityLabel("Command input")
		.accessibilityHint(isDisabled ? "Wait for the dungeon master" : "Type your next action")
	}
}

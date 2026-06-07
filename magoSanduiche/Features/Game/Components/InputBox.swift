//
//  InputBox.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 10/12/25.
//

import SwiftUI

struct InputBox: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var textbinding: Binding<String>
	var isDisabled: Bool
	var invalidAttempts: Int
	var onSubmit: () -> Void
	@FocusState.Binding var isFocused: Bool

	init(
		with bind: Binding<String>,
		isFocused: FocusState<Bool>.Binding,
		isDisabled: Bool = false,
		invalidAttempts: Int = 0,
		onSubmit: @escaping () -> Void = {}
	) {
		self.textbinding = bind
		self._isFocused = isFocused
		self.isDisabled = isDisabled
		self.invalidAttempts = invalidAttempts
		self.onSubmit = onSubmit
	}

	var body: some View {
		HStack(spacing: 8) {
			Text(">")
				.font(.monocraft(relativeTo: .headline, weight: .semibold))
				.foregroundStyle(isDisabled ? Color.terminalMutedText : Color.accent)

			TextField("nan_input_placeholder", text: textbinding)
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
		// .background(isFocused ? Color.terminalActiveSurface : Color.terminalSurface)
		.drawBorder(
			nil,
			color: isDisabled ? Color.terminalMutedText : Color.accent,
			lineWidth: isFocused ? 2 : 1
		)
		.opacity(isDisabled ? 0.65 : 1)
		.shakeOnInvalid(invalidAttempts: invalidAttempts, isEnabled: !reduceMotion)
		.onAppear {
			guard !isDisabled else { return }
			isFocused = true
		}
		.accessibilityLabel(String(localized: "nan_input_a11y_label"))
		.accessibilityHint(
			isDisabled
				? String(localized: "nan_input_a11y_hint_disabled")
				: String(localized: "nan_input_a11y_hint_enabled")
		)
	}
}

// MARK: - Shake

private extension View {
	/// Symmetric left/right shake driven by a `keyframeAnimator`. Each bump in
	/// `invalidAttempts` retriggers the full sequence; the animator self-
	/// terminates at offset `0` so there's no racing cleanup task.
	func shakeOnInvalid(invalidAttempts: Int, isEnabled: Bool) -> some View {
		modifier(InvalidShakeModifier(invalidAttempts: invalidAttempts, isEnabled: isEnabled))
	}
}

private struct InvalidShakeModifier: ViewModifier {
	let invalidAttempts: Int
	let isEnabled: Bool

	func body(content: Content) -> some View {
		content.keyframeAnimator(
			initialValue: CGFloat.zero,
			trigger: invalidAttempts
		) { view, offset in
			view.offset(x: isEnabled ? offset : 0)
		} keyframes: { _ in
			KeyframeTrack {
				CubicKeyframe(-6, duration: 0.06)
				CubicKeyframe(6, duration: 0.06)
				CubicKeyframe(-4, duration: 0.06)
				CubicKeyframe(4, duration: 0.06)
				CubicKeyframe(-2, duration: 0.06)
				CubicKeyframe(0, duration: 0.06)
			}
		}
	}
}

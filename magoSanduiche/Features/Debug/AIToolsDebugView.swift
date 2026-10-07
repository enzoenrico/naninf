#if DEBUG

	import SwiftUI

	struct AIToolsDebugView: View {
		var applyEffectsToGame: (([GameToolEffect]) -> Void)?
		var generateImage: ((String) async -> DebugImageGeneration)?

		@Environment(\.accessibilityReduceMotion) private var reduceMotion
		@Environment(\.dismiss) private var dismiss

		init(
			applyEffectsToGame: (([GameToolEffect]) -> Void)? = nil,
			generateImage: ((String) async -> DebugImageGeneration)? = nil
		) {
			self.applyEffectsToGame = applyEffectsToGame
			self.generateImage = generateImage
		}

		@State private var draft = DungeonTurnDraft.fixture()
		@State private var visualPrompt = String(localized: "nan_debug_ai_tools_image_sample")
		@State private var isGeneratingImage = false
		@State private var history: [String] = []

		var body: some View {
			AppLayout(background: .solid, scrollable: true) {
				VStack(alignment: .leading, spacing: 16) {
					header
					fieldControls

					Button {
						runDraft()
					} label: {
						Text("nan_debug_ai_tools_run")
							.font(.monocraft(relativeTo: .headline, weight: .semibold))
							.frame(maxWidth: .infinity)
							.padding(.vertical, 14)
					}
					.buttonStyle(OnboardingPrimaryButtonStyle())

					imageGeneration

					VStack(alignment: .leading, spacing: 8) {
						Text("nan_debug_ai_tools_output")
							.font(.monocraft(relativeTo: .caption, weight: .semibold))
							.foregroundStyle(Color.terminalWarning)
						if history.isEmpty {
							Text("nan_debug_ai_tools_output_empty")
								.font(.monocraft(relativeTo: .caption2, weight: .semibold))
								.foregroundStyle(Color.terminalMutedText)
						} else {
							ScrollView {
								Text(history.joined(separator: "\n\n—\n\n"))
									.font(.monocraft(relativeTo: .caption, weight: .semibold))
									.foregroundStyle(Color.terminalMana)
									.frame(maxWidth: .infinity, alignment: .leading)
									.textSelection(.enabled)
							}
							.frame(minHeight: 120)
							.padding(10)
							.drawBorder(nil, color: .terminalWarning.opacity(0.5), lineWidth: 1)
						}
					}

					Text("nan_debug_ai_tools_footnote")
						.font(.monocraft(relativeTo: .caption2, weight: .semibold))
						.foregroundStyle(Color.terminalMutedText)
						.fixedSize(horizontal: false, vertical: true)

					Spacer(minLength: 12)
				}
			}
			.navigationTitle(String(localized: "nan_debug_ai_tools_title"))
			.navigationBarTitleDisplayMode(.inline)
		}

		private var header: some View {
			VStack(alignment: .leading, spacing: 6) {
				Text("nan_debug_ai_tools_kicker")
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
					.foregroundStyle(Color.terminalMana)
				Text("nan_debug_ai_tools_heading")
					.font(.monocraft(relativeTo: .title3, weight: .bold))
					.foregroundStyle(Color.accent)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}

		private var fieldControls: some View {
			VStack(alignment: .leading, spacing: 10) {
				Stepper(value: $draft.healthChange, in: DungeonTurnDraft.healthRange) {
					Text("healthChange: \(draft.healthChange)")
						.font(.monocraft(relativeTo: .callout, weight: .semibold))
				}
				Stepper(value: $draft.manaChange, in: DungeonTurnDraft.manaRange) {
					Text("manaChange: \(draft.manaChange)")
						.font(.monocraft(relativeTo: .callout, weight: .semibold))
				}
				Picker(selection: $draft.nextInput) {
					Text("nan_debug_ai_tools_action_text").tag(NextInput.write)
					Text("nan_debug_ai_tools_action_dice").tag(NextInput.roll)
				} label: {
					Text("nan_debug_ai_tools_action_label")
				}
				.pickerStyle(.segmented)
			}
			.foregroundStyle(Color.accent)
		}

		private var imageGeneration: some View {
			VStack(alignment: .leading, spacing: 10) {
				Text("nan_debug_ai_tools_image_heading")
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
					.foregroundStyle(Color.terminalWarning)

				TextField("nan_debug_ai_tools_image_placeholder", text: $visualPrompt, axis: .vertical)
					.lineLimit(2...4)
					.font(.monocraft(relativeTo: .caption))
					.foregroundStyle(Color.accent)
					.textInputAutocapitalization(.sentences)
					.padding(10)
					.drawBorder(nil, color: .terminalWarning.opacity(0.5), lineWidth: 1)
					.disabled(isGeneratingImage)

				Button {
					Task { await runImageGeneration() }
				} label: {
					Group {
						if isGeneratingImage {
							Text("nan_debug_ai_tools_image_generating")
						} else {
							Text("nan_debug_ai_tools_generate_image")
						}
					}
					.font(.monocraft(relativeTo: .headline, weight: .semibold))
					.frame(maxWidth: .infinity)
					.padding(.vertical, 14)
				}
				.buttonStyle(OnboardingPrimaryButtonStyle())
				.disabled(isGeneratingImage)
			}
		}

		private func runDraft() {
			let effects = draft.resolved().toolEffects
			let effectsDescription = effects.map(\.description).joined(separator: ", ")
			let block = "EFFECTS: \(effectsDescription)"
			record(block)
			applyEffectsToGame?(effects)
		}

		private func runImageGeneration() async {
			let trimmed = visualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else {
				record(String(localized: "nan_debug_ai_tools_image_empty"))
				return
			}
			guard let generateImage else {
				record(String(localized: "nan_debug_ai_tools_image_unattached"))
				return
			}

			isGeneratingImage = true
			defer { isGeneratingImage = false }

			let result = await generateImage(trimmed)
			record(result.message)
			if result.didProduceImage || result.shouldDismiss {
				dismiss()
			}
		}

		private func record(_ block: String) {
			TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
				history.insert(block, at: 0)
				while history.count > 20 {
					history.removeLast()
				}
			}
		}
	}

	#Preview {
		NavigationStack {
			AIToolsDebugView()
		}
	}

#endif

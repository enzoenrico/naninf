#if DEBUG

	import SwiftUI

	struct AIToolsDebugView: View {
		var applyEffectsToGame: (([GameToolEffect]) -> Void)?

		private let tools = DungeonMasterService.modelTools

		@Environment(\.accessibilityReduceMotion) private var reduceMotion

		init(applyEffectsToGame: (([GameToolEffect]) -> Void)? = nil) {
			self.applyEffectsToGame = applyEffectsToGame
		}

		@State private var selectedToolIndex = 0
		@State private var useRawJSON = false
		@State private var rawJSONText = ""
		@State private var argumentValues: [String: Int] = [:]
		@State private var history: [String] = []
		@State private var isRunning = false

		private var selectedTool: AnyModelTool {
			tools[selectedToolIndex]
		}

		var body: some View {
			AppLayout(background: .solid, scrollable: true) {
				VStack(alignment: .leading, spacing: 16) {
					header

					VStack(alignment: .leading, spacing: 8) {
						Text("nan_debug_ai_tools_pick_tool")
							.font(.monocraft(relativeTo: .caption, weight: .semibold))
							.foregroundStyle(Color.terminalMana)
						Picker(selection: $selectedToolIndex) {
							ForEach(Array(tools.enumerated()), id: \.offset) { offset, tool in
								Text(tool.name).tag(offset)
							}
						} label: {
							EmptyView()
						}
						.pickerStyle(.menu)
						.onChange(of: selectedToolIndex) { _, _ in
							syncDefaultArgumentsJSON()
						}
					}

					argumentControls

					Toggle(isOn: $useRawJSON) {
						Text("nan_debug_ai_tools_raw_json")
							.font(.monocraft(relativeTo: .callout, weight: .semibold))
					}
					.tint(.terminalMana)

					if useRawJSON {
						TextEditor(text: $rawJSONText)
							.font(.monocraft(relativeTo: .caption, weight: .semibold))
							.foregroundStyle(Color.accent)
							.scrollContentBackground(.hidden)
							.frame(minHeight: 100)
							.padding(8)
							.drawBorder(nil, color: .terminalMutedText, lineWidth: 1)
					}

					Button {
						runSelectedTool()
					} label: {
						Text("nan_debug_ai_tools_run")
							.font(.monocraft(relativeTo: .headline, weight: .semibold))
							.frame(maxWidth: .infinity)
							.padding(.vertical, 14)
					}
					.buttonStyle(OnboardingPrimaryButtonStyle())
					.disabled(
						isRunning || (useRawJSON && rawJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					)

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
			.onAppear {
				syncDefaultArgumentsJSON()
			}
		}

		// MARK: - Subviews

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

		@ViewBuilder
		private var argumentControls: some View {
			VStack(alignment: .leading, spacing: 10) {
				Text("nan_debug_ai_tools_arguments")
					.font(.monocraft(relativeTo: .caption, weight: .semibold))
					.foregroundStyle(Color.terminalMana)

				if selectedTool.parameters.integerFields.isEmpty {
					Text("nan_debug_ai_tools_unknown_tool")
						.font(.monocraft(relativeTo: .caption2, weight: .semibold))
						.foregroundStyle(Color.terminalMutedText)
				} else {
					ForEach(selectedTool.parameters.integerFields) { field in
						integerControl(for: field)
					}
				}
			}
		}

		@ViewBuilder
		private func integerControl(for field: ToolIntegerParameter) -> some View {
			VStack(alignment: .leading, spacing: 6) {
				Text(field.description)
					.font(.monocraft(relativeTo: .caption2, weight: .semibold))
					.foregroundStyle(Color.terminalMutedText)
					.fixedSize(horizontal: false, vertical: true)

				if field.name == "action", field.minimum == 0, field.maximum == 1 {
					Picker(selection: argumentBinding(for: field)) {
						Text("nan_debug_ai_tools_action_text").tag(0)
						Text("nan_debug_ai_tools_action_dice").tag(1)
					} label: {
						Text("nan_debug_ai_tools_action_label")
					}
					.pickerStyle(.segmented)
				} else {
					Stepper(value: argumentBinding(for: field), in: field.closedRange) {
						Text("\(field.name): \(argumentValue(for: field))")
							.font(.monocraft(relativeTo: .callout, weight: .semibold))
					}
					.foregroundStyle(Color.accent)
				}
			}
		}

		// MARK: - Actions

		private func argumentValue(for field: ToolIntegerParameter) -> Int {
			argumentValues[field.name] ?? field.defaultValue
		}

		private func argumentBinding(for field: ToolIntegerParameter) -> Binding<Int> {
			Binding {
				argumentValue(for: field)
			} set: { newValue in
				argumentValues[field.name] = clamped(newValue, for: field)
				syncDefaultArgumentsJSONIfNotRaw()
			}
		}

		private func clamped(_ value: Int, for field: ToolIntegerParameter) -> Int {
			min(field.maximum ?? value, max(field.minimum ?? value, value))
		}

		private func syncDefaultArgumentsJSONIfNotRaw() {
			guard !useRawJSON else { return }
			syncDefaultArgumentsJSON()
		}

		private func syncDefaultArgumentsJSON() {
			argumentValues = selectedTool.parameters.defaultArgumentValues().merging(argumentValues) { _, current in
				current
			}
			rawJSONText = selectedTool.parameters.jsonString(argumentValues: argumentValues)
		}

		private func runSelectedTool() {
			let toolName = selectedTool.name
			let trimmedRaw = rawJSONText.trimmingCharacters(in: .whitespacesAndNewlines)
			let json: String
			if useRawJSON {
				guard !trimmedRaw.isEmpty else { return }
				json = trimmedRaw
			} else {
				json = selectedTool.parameters.jsonString(argumentValues: argumentValues)
			}

			isRunning = true
			let tool = selectedTool
			let reduceMotion = reduceMotion

			Task {
				let block: String
				let toolEffects: [GameToolEffect]?
				do {
					let result = try await tool.call(jsonArguments: json)
					let effectsDescription =
						result.effects.isEmpty
						? "none"
						: result.effects.map(\.description).joined(separator: ", ")
					block = "[\(toolName)] → \(result.modelMessage)\nEFFECTS: \(effectsDescription)\nARGS: \(json)"
					toolEffects = result.effects
				} catch {
					block = "[\(toolName)] ERROR: \(error.localizedDescription)\nARGS: \(json)"
					toolEffects = nil
				}
				await MainActor.run {
					TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
						history.insert(block, at: 0)
						while history.count > 20 {
							history.removeLast()
						}
						isRunning = false
						if let toolEffects {
							applyEffectsToGame?(toolEffects)
						}
					}
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

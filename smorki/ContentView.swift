//
//  ContentView.swift
//  smorki
//
//  Created by Enzo Enrico on 30/07/25.
//

import FirebaseAI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let actionPromptMarker = "What do you do?"

struct ContentView: View {
  @StateObject private var ascii = Ascii(targetWidth: 150)
  @EnvironmentObject private var obs: Observability
  @State private var showModal = false
  @State var userInput = "> "
  @State private var messageHistory: [Message] = []
  @State private var currentGifData: Message.GifData?
  @State var dynamicH: Double = 35.0

  @State private var showResetModal = false
  @State private var isGameEnded = false

  @State private var uiOpacity = 0.0

  private func startScreen() {
    if let opening = Bundle.main.url(forResource: "opening", withExtension: "mp4") {
      let placeholderGifData = Message.GifData(
        url: opening,
        frameCount: 0,
        aspectRatio: 1.0
      )
      let introMessage = Message(
        title: "> Welcome, Mage!",
        response:
          """
          Breathe, traveler. The way back is sealed. There is only the path forward.

          Welcome to the heart of the forgotten. This place you see... it is more than mere stone and shadow. It is a living puzzle, a labyrinth of secrets designed to guard a prize of immense power: the Scroll of Aethelgard.

          Our journey will not be a simple one. The main corridors may lead only to ruin and despair. You must look deeper. Examine the walls for hidden switches, listen for the echo in hollow floors, and understand that the dungeon itself will try to deceive you. New paths will reveal themselves only to a keen eye and a clever mind.

          Danger lurks in every shadow, but do not let fear master you. Your courage is a light as potent as the one from my staff. Together, we will navigate its depths, uncover its long-lost ways, and claim the power that lies waiting.

          Now... take the first step. Our true journey begins.

          > Type your commands to interact with the world.
          """,
        gifData: placeholderGifData,
      )
      messageHistory.append(introMessage)

      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {

        withAnimation(.easeInOut(duration: 1.5)) {
          uiOpacity = 1.0
        }
      }
    }
  }

  @EnvironmentObject var ai: AiManager
  var body: some View {

    GeometryReader { geometry in
      ZStack {
        VStack(spacing: 0) {
          ScrollViewReader { proxy in
            ScrollView {
              LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(messageHistory, id: \.id) { message in
                  MessageView(
                    message: message,
                    fontSize: calculateFontSize(for: geometry.size)
                  )
                  .id(message.id)
                }
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: messageHistory.count) { _ in
              if let last = messageHistory.last {
                withAnimation(.interpolatingSpring) {
                  proxy.scrollTo(last.id, anchor: .bottom)
                }
              }
              obs.logNewMessage(messageCount: messageHistory.count)
            }
          }

          InputField(
            textContent: $userInput,
            onSubmit: { await submitMessage(nil) },
            resetAdventure: resetAdventure,
            showModal: $showModal,
            showResetModal: $showResetModal,
            isGameEnded: $isGameEnded,

          )
          .padding()
        }
        .opacity(uiOpacity)

        if self.showModal {
          ActionModal(
            userInput: $userInput,
            dynamicH: $dynamicH,
            showModal: $showModal,
            submitMessageSync: submitMessageSync,
            options: extractOptions(from: messageHistory.last?.response ?? "")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.black)
          .zIndex(3)
        }

        if self.showResetModal {
          ResetAdventureModal(isPresented: $showResetModal) {
            resetAdventure()
          }
          .frame(width: .infinity, height: .infinity)
        }
      }
    }
    .onAppear {
      if messageHistory.isEmpty {
        startScreen()
      }
    }
    .onDisappear {
      obs.logSessionEnded(messageCount: messageHistory.count)
    }
    .enableInjection()
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif

  private func resetAdventure() {
    let endMessage = Message(title: "> Adventure Ended", isLoading: true)
    self.messageHistory.append(endMessage)

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      self.messageHistory.removeAll()
      self.isGameEnded = false
      self.uiOpacity = 0.0
      startScreen()
    }
  }

  private func loadBundledVideo(prompt: String) async {
    await withCheckedContinuation { continuation in
      Task.detached {
        var videoURL: URL?
        if let imageAsset = await self.ai.generateImage(prompt) {
          print("Image successful")
          if let data = imageAsset.pngData() {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".png")
            try? data.write(to: fileURL)
            videoURL = fileURL
            print(fileURL)
          }
        }
        else {
          print("No AI video available, using fallback video")
          videoURL = URL(
            string: "https://v3.fal.media/files/panda/GlYLge7xLsr9K39M33kG3_output.mp4")!
        }

        guard let finalURL = videoURL else {
          continuation.resume()
          return
        }

        await self.ascii.loadVideo(url: finalURL)
        await self.ascii.startConversion()

        let videoData = Message.GifData(
          url: finalURL,
          frameCount: await self.ascii.frameCount,
          aspectRatio: await self.ascii.aspectRatio
        )

        await MainActor.run {
          self.currentGifData = videoData
        }

        continuation.resume()
      }
    }
  }

  private func loadVideoQuery(generated_result: String, trimmedInput: String) async throws
    -> GenerateContentResponse
  {
    let maxResponseLength = 1500

    let lengthTruncatedResult =
      generated_result.count > maxResponseLength
      ? String(generated_result.prefix(maxResponseLength)) + "..."
      : generated_result

    let finalResult: String
    if let whatDoYouDoRange = lengthTruncatedResult.range(
      of: actionPromptMarker, options: .caseInsensitive)
    {
      finalResult = String(lengthTruncatedResult[..<whatDoYouDoRange.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      finalResult = lengthTruncatedResult
    }

    let escapedResult =
      finalResult
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\t", with: "\\t")

    let escapedInput =
      trimmedInput
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\t", with: "\\t")

    let video_prompt = try await ai.generatorChat.sendMessage([
      .init(
        parts:
          """
          {
            "system_response": "\(escapedResult)",
            "user_input": "\(escapedInput)"
          }
          """
      )
    ])
    return video_prompt
  }

  private func submitMessage(_ val: String?) async {
    let trimmedInput = val ?? userInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedInput != "> " && !trimmedInput.isEmpty else { return }

    await MainActor.run {
      let loadingMessage = Message(title: trimmedInput, isLoading: true)
      messageHistory.append(loadingMessage)
      userInput = "> "
    }

    var generated_result = "No response from model"

    do {
      let response = try await ai.chat.sendMessage([
        .init(role: "user", parts: trimmedInput)
      ]).text
      if let response = response {
        generated_result = response
        print("Generated response:")
        print(response)
      }
    } catch {
      print("No response from the model")
      print(error.localizedDescription)
      await MainActor.run {
        if let index = messageHistory.firstIndex(where: { $0.isLoading }) {
          messageHistory[index] = Message(
            title: trimmedInput,
            response: "Error: Could not generate story. Please try again.",
            gifData: nil
          )
        }
      }
      return
    }

    if let img_prompt = try? await loadVideoQuery(
      generated_result: generated_result, trimmedInput: trimmedInput)
    {
      await loadBundledVideo(prompt: img_prompt.text!)
    } else {
      print("no image prompt generated")
      return
    }

    let gifDataToUse = currentGifData

    await MainActor.run {
      if let index = messageHistory.firstIndex(where: { $0.isLoading }) {
        messageHistory[index] = Message(
          title: trimmedInput,
          response: generated_result,
          gifData: gifDataToUse
        )
      }

      ai.history.append(contentsOf: [
        ModelContent(role: "user", parts: trimmedInput),
        ModelContent(role: "system", parts: generated_result),
      ])
    }

    currentGifData = nil
  }

  private func submitMessageSync(_ val: String? = nil) {
    Task {
      showModal = false
      await submitMessage(val)
    }

  }

  func calculateFontSize(for size: CGSize) -> CGFloat {
    let availableWidth = size.width - 32
    let targetCharacterCount = CGFloat(ascii.targetWidth)

    let characterWidthRatio: CGFloat = 0.6
    let calculatedFontSize = availableWidth / (targetCharacterCount * characterWidthRatio)

    return max(min(calculatedFontSize, 20), 4)
  }
}

struct InputField: View {
  @Binding var textContent: String
  let onSubmit: () async -> Void
  let resetAdventure: () -> Void
  @State private var dynamicH: Double = 30.0
  @Binding var showModal: Bool

  @Binding var showResetModal: Bool
  @Binding var isGameEnded: Bool

  func modalToggle() {
    Task {
      showModal.toggle()
      if !showModal {
        await onSubmit()
      }

    }
  }

  var body: some View {
    HStack {
      Button(action: {
        if isGameEnded {
          resetAdventure()
        } else {
          modalToggle()
        }
      }) {
        Text(isGameEnded ? "► new quest" : "► act")
          .frame(maxWidth: .infinity)
          .padding()
          .foregroundColor(.green)
          .background {
            RoundedRectangle(cornerRadius: 8)
              .stroke(.green, lineWidth: 2)
          }
      }
      .disabled(self.isGameEnded)

      Button(action: {
        showResetModal = true
      }) {
        Image(systemName: "gear")
          .frame(maxWidth: 20)
          .padding()
          .foregroundColor(.green)
          .background {
            RoundedRectangle(cornerRadius: 8)
              .stroke(.green, lineWidth: 2)
          }
      }
    }
    .enableInjection()
  }

}

struct ActionOption: Identifiable {
  let id: String
  let text: String
}

private func extractOptions(from response: String) -> [ActionOption] {
  guard let range = response.range(of: actionPromptMarker, options: .caseInsensitive) else {
    return []
  }

  let tail = response[range.upperBound...]

  return tail
    .components(separatedBy: .newlines)
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .map { $0.replacingOccurrences(of: #"^>\s*"#, with: "", options: .regularExpression) }
    .filter { !$0.isEmpty }
    .compactMap { option in
      guard let match = option.range(of: #"^[A-Z]\.\s"#, options: .regularExpression) else {
        return nil
      }

      let id = String(option[match]).trimmingCharacters(in: .whitespaces)
      let text = option[match.upperBound...].trimmingCharacters(in: .whitespaces)
      return ActionOption(id: id, text: text)
    }
}

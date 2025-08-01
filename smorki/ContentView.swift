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

// Message model to store history

struct ContentView: View {
  @StateObject private var ascii = Ascii(targetWidth: 150)
  @State private var showModal = false
  @State private var selectedGIFURL: URL?
  @State private var lastFrame: Int?
  @State var userInput = "> "
  @State private var messageHistory: [Message] = []
  @State private var currentGifData: Message.GifData?
  @State var dynamicH: Double = 35.0

  // Add these state variables to your ContentView
  @State private var showResetModal = false
  @State private var isGameEnded = false

  private func startScreen() {
    if let gifURL = Bundle.main.url(forResource: "demo", withExtension: "gif") {
      let placeholderGifData = Message.GifData(
        url: gifURL,
        frameCount: 0,
        aspectRatio: 1.0
      )
      let introMessage = Message(
        title: "> Welcome, Mage!",
        response: "Your adventure begins now. Prepare to enter the dungeon...",
        gifData: placeholderGifData,

      )
      messageHistory.append(introMessage)
    }
  }

  @EnvironmentObject var ai: AiManager
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        VStack(spacing: 0) {
          // Message history feed
          ScrollViewReader { proxy in
            ScrollView {
              LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(messageHistory) { message in
                  MessageView(
                    message: message,
                    fontSize: calculateFontSize(for: geometry.size)
                  )
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
            }
          }

          InputField(
            textContent: $userInput,
            onSubmit: submitMessage,
            resetAdventure: resetAdventure,
            showModal: $showModal,
            showResetModal: $showResetModal,
            isGameEnded: $isGameEnded
          )
          .padding()
        }

        if self.showModal {
          ActionModal(
            userInput: $userInput,
            dynamicH: $dynamicH,
            showModal: $showModal,
            submitMessageSync: submitMessageSync
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
    // .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      if messageHistory.isEmpty {
        startScreen()
      }
    }
    .enableInjection()

  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif

  private func resetAdventure() {
    // Send final message to end the adventure
    let endMessage = Message(title: "> Adventure Ended", isLoading: true)
    self.messageHistory.append(endMessage)

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      self.messageHistory.removeAll()
      self.isGameEnded = false
      startScreen()
    }

  }

  private func loadBundledGIF(path: String) {
    guard let gifURL = Bundle.main.url(forResource: path, withExtension: "gif") else {
      return
    }

    ascii.loadGIF(from: gifURL)
    ascii.startConversion()

    // Create gif data for history
    let gifData = Message.GifData(
      url: gifURL,
      frameCount: 0,
      aspectRatio: ascii.aspectRatio
    )
    self.currentGifData = gifData
  }

  private func submitMessage() async {
    let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedInput == "> " || !trimmedInput.isEmpty || currentGifData != nil else { return }

    // Create loading message immediately
    let loadingMessage = Message(title: trimmedInput, isLoading: true)
    messageHistory.append(loadingMessage)

    // Clear input and reset UI state
    userInput = "> "
    currentGifData = nil

    var generated_result = "No response from model"
    do {
      let response = try await ai.chat.sendMessage([
        .init(role: "user", parts: trimmedInput)
      ]).text
      if let response = response {
        generated_result = response
      }
    } catch {
      print("no response from the model")
      print(error.localizedDescription)

      if let index = messageHistory.firstIndex(where: { $0.id == loadingMessage.id }) {
        messageHistory[index] = Message(
          title: trimmedInput,
          response: "Error: Could not generate story. Please try again.",
          gifData: nil
        )
      }
      return
    }

    // Load GIF after successful response
    // update to model's gif
    self.loadBundledGIF(path: "veo3_wizard_refined")

    // Replace loading message with completed message
    if let index = messageHistory.firstIndex(where: { $0.id == loadingMessage.id }) {
      messageHistory[index] = Message(
        title: trimmedInput,
        response: generated_result,
        gifData: currentGifData
      )
    }

    // Update AI history
    ai.history.append(contentsOf: [
      ModelContent(
        role: "user",
        parts: trimmedInput
      ),
      ModelContent(
        role: "system",
        parts: generated_result
      ),
    ])

    currentGifData = nil
  }

  private func submitMessageSync() {
    Task {
      showModal = false
      await submitMessage()
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

  func handleContentChange(_ s: String) {
    if !s.hasPrefix(">") {
      textContent = ">" + s
    }
  }

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
          // .tint(.green)
          .background {
            RoundedRectangle(cornerRadius: 8)
              .stroke(.green, lineWidth: 2)
          }
      }
      Button(action: {
        showResetModal = true
      }) {
        Image(systemName: "gear")
          .frame(maxWidth: 20)
          .padding()
          .foregroundColor(.green)
          // .tint(.green)
          .background {
            RoundedRectangle(cornerRadius: 8)
              .stroke(.green, lineWidth: 2)
          }
      }
    }
    .enableInjection()
  }

}

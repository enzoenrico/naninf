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
  @State private var messageHistory: [Message] = [
    Message(
      title: "The adventure starts", response: "Lorem", timestamp: Date(),
      gifData: Message.GifData(url: URL(string: "demo.gif")!, frameCount: 27, aspectRatio: 1.0))
  ]
  @State private var currentGifData: Message.GifData?
  @State var dynamicH: Double = 35.0

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
            showModal: $showModal
          )
          .padding()
        }

        if self.showModal {
          VStack {
            VStack(spacing: 0) {
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green, lineWidth: 2)
                .overlay(alignment: .topLeading) {
                  VStack(alignment: .leading, spacing: 0) {
                    Text("Your next action here")
                      .padding(.horizontal, 2)
                      .background(.black)
                      // .font(.caption)
                      .foregroundColor(.green)
                      .zIndex(3)
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .padding(.horizontal, 8)
                      .offset(y: -8)

                    TextEditor(text: $userInput)
                      .frame(minHeight: dynamicH, maxHeight: dynamicH)  // Use minHeight/maxHeight to hug
                      // .padding(8)
                      .foregroundColor(.green)
                      .tint(.green)
                      .onChange(of: userInput) { result in
                        withAnimation(.interpolatingSpring) {
                          dynamicH = result.count <= 75 ? 35 : 100
                        }
                      }
                      .onSubmit {
                        submitMessageSync()
                      }
                  }
                  .padding(.horizontal, 8)
                }
                .padding(.horizontal)
            }
            .frame(minHeight: dynamicH + 32, maxHeight: dynamicH + 32)  // Use minHeight/maxHeight to hug

            HStack(spacing: 10) {

              Button(action: {
                self.showModal = false
              }) {
                Text("◄ go back")
                  .frame(maxWidth: 80)
                  .padding()
                  .foregroundColor(.green)
                  .background {
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(.green, lineWidth: 2)
                  }
              }

              Button(action: submitMessageSync) {
                Text("► send")
                  .frame(maxWidth: .infinity)
                  .padding()
                  .foregroundColor(.green)
                  .background {
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(.green, lineWidth: 2)
                  }
              }
            }
            .padding(.horizontal)

          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.black)
          .zIndex(3)
        }
      }
    }
    // .frame(maxWidth: .infinity, maxHeight: .infinity)
    .enableInjection()
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif

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
    guard !trimmedInput.isEmpty || currentGifData != nil else { return }

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
      return

    }

    self.loadBundledGIF(path: "veo3_wizard_refined")

    let message = Message(
      title: trimmedInput,
      response: generated_result,
      timestamp: Date(),
      gifData: currentGifData
    )

    messageHistory.append(message)
    //turn this into a function to sync both histories
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
    userInput = "> "
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
  @State private var dynamicH: Double = 30.0
  @Binding var showModal: Bool

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
      Button(action: modalToggle) {
        Text("► act")
          .frame(maxWidth: .infinity)
          .padding()
          .foregroundColor(.green)
          // .tint(.green)
          .background {
            RoundedRectangle(cornerRadius: 8)
              .stroke(.green, lineWidth: 2)
          }
      }
      Button(action: modalToggle) {
        Image(systemName: "gearshape")
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

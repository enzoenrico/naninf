//
//  ContentView.swift
//  smorki
//
//  Created by Enzo Enrico on 30/07/25.
//

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
            }
          }

          InputField(
            textContent: $userInput,
            onSubmit: { submitMessage() },
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
                  }
                  .padding(.horizontal, 8)
                }
                .padding(.horizontal)
            }
            .frame(minHeight: dynamicH + 32, maxHeight: dynamicH + 32)  // Use minHeight/maxHeight to hug

            Button(action: {
              showModal = false
              submitMessage()
            }) {
              Text("play")
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.green)
                .background {
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(.green, lineWidth: 2)
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

  private func submitMessage() {
    let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty || currentGifData != nil else { return }

    self.loadBundledGIF(path: "veo2_wizard")

    let message = Message(
      text: trimmedInput,
      timestamp: Date(),
      gifData: currentGifData
    )

    messageHistory.append(message)
    userInput = "> "
    currentGifData = nil
  }

  private func calculateFontSize(for size: CGSize) -> CGFloat {
    let availableWidth = size.width - 32
    let targetCharacterCount = CGFloat(ascii.targetWidth)

    let characterWidthRatio: CGFloat = 0.6
    let calculatedFontSize = availableWidth / (targetCharacterCount * characterWidthRatio)

    return max(min(calculatedFontSize, 20), 4)
  }
}

struct InputField: View {
  @Binding var textContent: String
  let onSubmit: () -> Void
  @State private var dynamicH: Double = 30.0
  @Binding var showModal: Bool

  func handleContentChange(_ s: String) {
    if !s.hasPrefix(">") {
      textContent = ">" + s
    }
  }

  func modalToggle() {
      Task{
          showModal.toggle()
            print("calling")
          let f = try? await AiManager().ai.generateContent("print a hello world now")
          print(f?.text ?? "naoooo se fudeu")
          print(" end")
          if !showModal {
          onSubmit()
        }
      }
  }

  var body: some View {
    VStack {

      Button(action: modalToggle) {
        Text("play")
          .frame(maxWidth: .infinity)
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

// private struct ButtonGroup: View {
//   let ascii: Ascii
//   let onGifLoad: (Message.GifData) -> Void

//   var body: some View {
//     VStack {
//       HStack {
//         Button("Stop") {
//           ascii.stopConversion()
//         }
//         .buttonStyle(.bordered)

//         Button("Wizard") {
//           ascii.stopConversion()

//           loadBundledGIF(path: "veo2_wizard")
//         }
//         .buttonStyle(.bordered)

//         Button("Demo GIF") {
//           ascii.stopConversion()
//           loadBundledGIF(path: "demo")
//         }
//         .buttonStyle(.borderedProminent)
//       }
//     }
//     .enableInjection()
//   }

//   #if DEBUG
//     @ObserveInjection var forceRedraw
//   #endif

//   // Function to load the bundled GIF
//   private func loadBundledGIF(path: String, frame: Int? = nil) {
//     guard let gifURL = Bundle.main.url(forResource: path, withExtension: "gif") else {
//       return
//     }
//     ascii.loadGIF(from: gifURL)
//     ascii.startConversion(frame)

//     // Create gif data for history
//     let gifData = Message.GifData(
//       url: gifURL,
//       frameCount: 0,  // You might want to get this from ascii object
//       aspectRatio: ascii.aspectRatio
//     )
//     onGifLoad(gifData)
//   }
// }

// Date formatter extension
extension DateFormatter {
  static let messageTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }()
}

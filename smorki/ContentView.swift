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
  @State private var showingFilePicker = false
  @State private var selectedGIFURL: URL?
  @State private var lastFrame: Int?
  @State var userInput = "> "
  @State private var messageHistory: [Message] = []
  @State private var currentGifData: Message.GifData?

  var body: some View {
    GeometryReader { geometry in
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
          onSubmit: { submitMessage() }
        )
        .padding()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

  // Calculate font size to fill viewport width with target character count
  private func calculateFontSize(for size: CGSize) -> CGFloat {
    let availableWidth = size.width - 32  // Account for padding
    let targetCharacterCount = CGFloat(ascii.targetWidth)

    let characterWidthRatio: CGFloat = 0.6
    let calculatedFontSize = availableWidth / (targetCharacterCount * characterWidthRatio)

    // Ensure reasonable bounds
    return max(min(calculatedFontSize, 20), 4)
  }
}

// Individual message view with its own ASCII renderer for GIFs

struct InputField: View {
  @Binding var textContent: String
  let onSubmit: () -> Void
  @State private var dynamicH: Double = 30.0

  func handleContentChange(_ s: String) {
    if !s.hasPrefix(">") {
      textContent = ">" + s
    }
  }

  var body: some View {
    VStack {
      TextEditor(text: $textContent)
        .frame(width: .infinity, height: dynamicH)
        .padding(8)
        .border(.green)
        .foregroundColor(.green)
        .tint(.green)
        .onChange(of: textContent) { result in
          handleContentChange(result)
          withAnimation(.interpolatingSpring) {
            dynamicH = result.count <= 75 ? 30 : 100
          }
        }

      Button(action: onSubmit) {
        Text("Send Message")
          .frame(maxWidth: .infinity)
          .padding()
          .border(.green, width: 2)
          .foregroundColor(.green)
          .tint(.green)
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

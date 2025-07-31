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
struct Message: Identifiable {
  let id = UUID()
  let text: String
  let timestamp: Date
  let gifData: GifData?
  
  struct GifData {
    let url: URL
    let frameCount: Int
    let aspectRatio: Double
  }
}

struct ContentView: View {
  @StateObject private var ascii = Ascii(targetWidth: 120)
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
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(messageHistory) { message in
              MessageView(
                message: message,
                fontSize: calculateFontSize(for: geometry.size)
              )
            }
            
            // Current live message and GIF
            // if !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ascii.currentFrame != "" {
            //   VStack(alignment: .leading, spacing: 8) {
            //     // if !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            //     //   Text(userInput)
            //     //     .font(.system(size: calculateFontSize(for: geometry.size), design: .monospaced))
            //     //     .foregroundColor(.green)
            //     //     .frame(maxWidth: .infinity, alignment: .leading)
            //     // }
                
            //     // if ascii.currentFrame != "" {
            //     //   Text(ascii.currentFrame)
            //     //     .font(.system(size: calculateFontSize(for: geometry.size), design: .monospaced))
            //     //     .lineLimit(nil)
            //     //     .foregroundColor(.green)
            //     //     .aspectRatio(ascii.aspectRatio, contentMode: .fit)
            //     //     .frame(maxWidth: .infinity)
            //     // }
            //   }
            //   .padding(.horizontal)
            // }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        ButtonGroup(ascii: ascii, onGifLoad: { gifData in
          currentGifData = gifData
        })
        .padding()

        VStack {
          Text("width: \(ascii.targetWidth)")
            .font(.caption)
        }

        InputField(
          textContent: $userInput,
          onSubmit: { submitMessage() }
        )
        .padding(.horizontal)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .enableInjection()
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif

  private func submitMessage() {
    let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty || currentGifData != nil else { return }
    
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
struct MessageView: View {
  let message: Message
  let fontSize: CGFloat
  @StateObject private var messageAscii = Ascii(targetWidth: 80)
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(message.text)
          .font(.caption)
          .foregroundColor(.green)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      if let gifData = message.gifData {
        Text(messageAscii.currentFrame)
          .font(.system(size: fontSize, design: .monospaced))
          .lineLimit(nil)
          .foregroundColor(.green)
          .aspectRatio(gifData.aspectRatio, contentMode: .fit)
          .frame(maxWidth: .infinity)
          .onAppear {
            messageAscii.loadGIF(from: gifData.url)
            messageAscii.startConversion()
          }
          .onDisappear {
            messageAscii.stopConversion()
          }
      }
      Text(DateFormatter.messageTime.string(from: message.timestamp))
        .font(.caption2)
        .foregroundColor(.gray)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(.horizontal)
  }
}

struct InputField: View {
  @Binding var textContent: String
  let onSubmit: () -> Void

  func handleContentChange(_ s: String) {
    if !s.hasPrefix(">") {
      textContent = ">" + s
    }
  }

  var body: some View {
    VStack {
      TextEditor(text: $textContent)
        .frame(minHeight: 35, maxHeight: 100)
        .padding(8)
        .border(.green)
        .foregroundColor(.green)
        .tint(.green)
        .onChange(of: textContent) { result in
          handleContentChange(result)
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

private struct ButtonGroup: View {
  let ascii: Ascii
  let onGifLoad: (Message.GifData) -> Void
  
  var body: some View {
    VStack {
      HStack {
        Button("Stop") {
          ascii.stopConversion()
        }
        .buttonStyle(.bordered)

        Button("Wizard") {
          ascii.stopConversion()
            guard let videoURL = Bundle.main.url(forResource: "wizard_spider", withExtension: "mp4"),
              let videoData = try? Data(contentsOf: videoURL) else {
            print("Error loading wizard_spider.mp4 from bundle")
            return
            }

          ascii.loadGIF(from: videoData)
        }
        .buttonStyle(.bordered)

        Button("Demo GIF") {
          ascii.stopConversion()
          loadBundledGIF(path: "demo")
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .enableInjection()
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif

  // Function to load the bundled GIF
  private func loadBundledGIF(path: String, frame: Int? = nil) {
    guard let gifURL = Bundle.main.url(forResource: path, withExtension: "gif") else {
      return
    }
    ascii.loadGIF(from: gifURL)
    ascii.startConversion(frame)
    
    // Create gif data for history
    let gifData = Message.GifData(
      url: gifURL,
      frameCount: 0, // You might want to get this from ascii object
      aspectRatio: ascii.aspectRatio
    )
    onGifLoad(gifData)
  }
}

// Date formatter extension
extension DateFormatter {
  static let messageTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }()
}

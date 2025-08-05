import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct Message: Identifiable {
  let id = UUID()
  let title: String
  let response: String?
  let timestamp: Date
  var gifData: GifData?
  let isLoading: Bool

  struct GifData {
    let url: URL
    let frameCount: Int
    let aspectRatio: Double
  }

  // Convenience initializer for loading state
  init(title: String, isLoading: Bool = false) {
    self.title = title
    self.response = nil
    self.timestamp = Date()
    self.gifData = nil
    self.isLoading = isLoading
  }

  // Full initializer for completed message
  init(title: String, response: String, gifData: GifData? = nil) {
    self.title = title
    self.response = response
    self.timestamp = Date()
    self.gifData = gifData
    self.isLoading = false
  }

  // Method to update message with video data
  func withGifData(_ gifData: GifData?) -> Message {
    var updated = self
    updated.gifData = gifData
    return updated
  }
}

struct TypewriterText: View {
  let text: String
  let font: Font
  let color: Color
  let speed: Double

  @State private var displayedText: String = ""
  @State private var currentIndex: Int = 0

  init(
    _ text: String, font: Font = .departure(size: 14), color: Color = .green, speed: Double = 0.05
  ) {
    self.text = text
    self.font = font
    self.color = color
    self.speed = speed
  }

  var body: some View {
    Text(displayedText)
      .font(font)
      .foregroundColor(color)
      .onAppear {
        startTypewriting()
      }
      .onChange(of: text) { newText in
        resetAndStart()
      }
  }

  private func startTypewriting() {
    displayedText = ""
    currentIndex = 0
    typeNextCharacter()
  }

  private func resetAndStart() {
    displayedText = ""
    currentIndex = 0
    startTypewriting()
  }

  private func typeNextCharacter() {
    guard currentIndex < text.count else { return }

    let index = text.index(text.startIndex, offsetBy: currentIndex)
    displayedText.append(text[index])
    currentIndex += 1

    DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
      typeNextCharacter()
    }
  }
}

struct MessageView: View {
  var message: Message
  let fontSize: CGFloat

  @StateObject private var ascii = Ascii(targetWidth: 140)
  @State private var loadingAnimationIndex = 0

  private let loadingCharacters = ["▁", "▂", "▃", "▄", "▅", "▆", "▇"]

  fileprivate func LoadState() -> HStack<TupleView<(Text, some View)>> {
    return
      HStack {
        Text("Generating story")
          .foregroundColor(.green)

        Text(
          "\(loadingCharacters[loadingAnimationIndex])\(loadingCharacters[(loadingAnimationIndex + 1) % loadingCharacters.count])\(loadingCharacters[(loadingAnimationIndex + 2) % loadingCharacters.count])"
        )
        .foregroundColor(.green)
        .font(.departure(size: 14))
        .onAppear {
          startLoadingAnimation()
        }
      }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if message.isLoading {
        LoadState()
          .padding()
      } else if let response = message.response {
        // Typewriter response text
        TypewriterText(response, font: .departure(size: 14), speed: 0.01)
          .padding()

        if let gifData = message.gifData {
          Text(ascii.currentFrame)
            .font(.departure(size: fontSize))
            .lineLimit(nil)
            .foregroundColor(.green)
            .aspectRatio(gifData.aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .onAppear {
              // Load the video/gif from the gifData URL
              if gifData.url.pathExtension.lowercased() == "mp4" {
                Task {
                  await ascii.loadVideo(url: gifData.url)
                  await ascii.startConversion()
                }
              } else {
                ascii.loadGIF(from: gifData.url)
                ascii.startConversion()
              }
            }
            .onDisappear {
              ascii.stopConversion()
            }
            .padding(.top)
            .padding(.bottom)
            .id(message.id)
        }
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.green, lineWidth: 2)
        .overlay(alignment: .topLeading) {
          TypewriterText(message.title, font: .departure(size: 12), speed: 0.08)
            .lineLimit(1)
            .padding(.horizontal, 2)
            .background(.black)
            .zIndex(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .offset(y: -8)
        }
        .frame(maxWidth: .infinity)
    )
    .frame(maxWidth: .infinity)
    .padding(.horizontal)
    .enableInjection()
  }

  private func startLoadingAnimation() {
    Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
      if !message.isLoading {
        timer.invalidate()
        return
      }

      withAnimation(.easeInOut(duration: 0.1)) {
        loadingAnimationIndex = (loadingAnimationIndex + 1) % loadingCharacters.count
      }
    }
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif
}

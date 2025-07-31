import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct Message: Identifiable {
  let id = UUID()
  let text: String
  let timestamp: Date
  var gifData: GifData?

  struct GifData {
    let url: URL
    let frameCount: Int
    let aspectRatio: Double
  }
}

struct MessageView: View {
  var message: Message
  let fontSize: CGFloat

  @StateObject private var ascii = Ascii(targetWidth: 140)

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {

      // llm response goes here

      if let gifData = message.gifData {
        Text(ascii.currentFrame)
          // .font(.system(size: fontSize, design: .monospaced))
              .font(.departure(size: fontSize))
          .lineLimit(nil)
          .foregroundColor(.green)
          .aspectRatio(gifData.aspectRatio, contentMode: .fit)
          .frame(maxWidth: .infinity)
          .onAppear {
            ascii.loadGIF(from: gifData.url)
            ascii.startConversion()
          }
          .onDisappear {
            ascii.stopConversion()
          }
          .padding(.top)
          .padding(.bottom)
      }
      // Text(DateFormatter.messageTime.string(from: message.timestamp))
      //   .font(.caption2)
      //   .foregroundColor(.gray)
      //   .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.green, lineWidth: 2)
        .overlay(alignment: .topLeading) {
          Text(message.text.count < 3 ? "> The mage casts fireball" : message.text)
            .padding(.horizontal, 2)
            .background(.black)
              .font(.departure(size: 12))
            .foregroundColor(.green)
            .zIndex(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .offset(y: -8)
        }
    )
    .padding(.horizontal)
    .enableInjection()
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif
}

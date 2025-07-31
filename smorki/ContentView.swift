//
//  ContentView.swift
//  smorki
//
//  Created by Enzo Enrico on 30/07/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
  @StateObject private var ascii = Ascii(targetWidth: 80)
  @State private var showingFilePicker = false
  @State private var selectedGIFURL: URL?

  @State private var lastFrame: Int?

  var body: some View {
    GeometryReader { geometry in
      VStack {

        Text(ascii.currentFrame)
          .font(.system(size: calculateFontSize(for: geometry.size), design: .monospaced))
          .lineLimit(nil)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
          // .background(Color.blue)
          .foregroundColor(.green)
          .aspectRatio(ascii.aspectRatio, contentMode: .fit)

        VStack {
          HStack {
            Button("Stop") {
              ascii.stopConversion()
            }
            .buttonStyle(.bordered)

            Button("next") {
              ascii.stopConversion()
              loadBundledGIF(path: "ojos", frame: self.lastFrame ?? nil)

            }
            .buttonStyle(.bordered)

            Button("Use Default GIF") {
              ascii.stopConversion()
              loadBundledGIF(path: "demo", frame: self.lastFrame ?? nil)
            }
            .buttonStyle(.borderedProminent)

          }
          .padding()

          VStack {
            Text("ASCII Width: \(ascii.targetWidth)")
              .font(.caption)

            Slider(
              value: Binding(
                get: { Double(ascii.targetWidth) },
                set: { ascii.targetWidth = Int($0) }
              ),
              in: 20...150,
              step: 5
            )
            .padding(.horizontal)
          }
        }

      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .fileImporter(
      isPresented: $showingFilePicker,
      allowedContentTypes: [.gif],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          selectedGIFURL = url
        }
      case .failure(let error):
        print("File picker error: \(error)")
      }
    }
    .enableInjection()
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

  // Function to load the bundled GIF
  private func loadBundledGIF(path: String, frame: Int? = nil) {
    guard let gifURL = Bundle.main.url(forResource: path, withExtension: "gif") else {
      return
    }
    ascii.loadGIF(from: gifURL)
    ascii.startConversion(frame)
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif
}

import CoreImage
import Foundation
import ImageIO
import SwiftUI
import UIKit

class Ascii: ObservableObject {
  @Published var currentFrame: String = ""
  @Published var isProcessing: Bool = false
  @Published var aspectRatio: Double = 1.0
  @Published var targetWidth: Int = 80  // Make this @Published instead of @State

  private let frameRate = 0.1
  // More detailed ASCII character ramp for smoother gradients (dark to light)
  private let asciiChars = "@%$*+=-:. ".reversed()

  private var gifSource: CGImageSource?
  private var frameCount: Int = 0
  public var currentFrameIndex: Int
  private var timer: Timer?

  init(targetWidth: Int = 80, frame: Int? = nil) {
    self.targetWidth = targetWidth
    self.currentFrameIndex = frame ?? 0
  }

  func loadGIF(from url: URL) {
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      print("Failed to create image source from URL")
      return
    }

    self.gifSource = imageSource
    self.frameCount = CGImageSourceGetCount(imageSource)
    self.currentFrameIndex = 0

    print("Loaded GIF with \(frameCount) frames")
  }

  // Load GIF from Data
  func loadGIF(from data: Data) {
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
      print("Failed to create image source from data")
      return
    }

    self.gifSource = imageSource
    self.frameCount = CGImageSourceGetCount(imageSource)
    self.currentFrameIndex = 0

    print("Loaded GIF with \(frameCount) frames")
  }

  public func calculateOptimalFontSize(for size: CGSize) -> CGFloat {
    let baseSize: CGFloat = min(size.width / CGFloat(self.targetWidth) * 0.8, 12)
    return max(baseSize, 4)  // Minimum font size of 4
  }

  // Start real-time ASCII conversion
  func startConversion(_ frameIndex: Int? = nil) {
    guard gifSource != nil, frameCount > 0 else {
      print("No GIF loaded")
      return
    }

    isProcessing = true
    timer = Timer.scheduledTimer(withTimeInterval: self.frameRate, repeats: true) { [weak self] _ in
      self?.processNextFrame(fixedIndex: frameIndex)
    }
  }

  // Stop the conversion
  func stopConversion() {
    isProcessing = false
    timer?.invalidate()
    timer = nil
  }

  // Process the next frame in sequence
  private func processNextFrame(fixedIndex: Int? = nil) {
    guard let gifSource = gifSource else { return }

    let frameIndex: Int
    if let fixedIndex = fixedIndex {
      // Use fixed frame index, don't increment
      frameIndex = min(fixedIndex, frameCount - 1)
    } else {
      // Sequential playback, use and increment currentFrameIndex
      frameIndex = currentFrameIndex % frameCount
    }

    if let cgImage = CGImageSourceCreateImageAtIndex(gifSource, frameIndex, nil) {
      let asciiString = convertImageToASCII(cgImage: cgImage)

      DispatchQueue.main.async {
        self.currentFrame = asciiString
      }
    }

    // Only increment for sequential playback
    if fixedIndex == nil {
      currentFrameIndex = (currentFrameIndex + 1) % frameCount
    }
  }

  // Convert a single frame to ASCII
  func convertFrameToASCII(frameIndex: Int) -> String? {
    guard let gifSource = gifSource,
      frameIndex < frameCount,
      let cgImage = CGImageSourceCreateImageAtIndex(gifSource, frameIndex, nil)
    else {
      return nil
    }

    return convertImageToASCII(cgImage: cgImage)
  }

  // Core ASCII conversion function with improved aspect ratio handling
  private func convertImageToASCII(cgImage: CGImage) -> String {
    let originalWidth = cgImage.width
    let originalHeight = cgImage.height

    // Calculate and store aspect ratio for UI
    let imageAspectRatio = Double(originalWidth) / Double(originalHeight)
    DispatchQueue.main.async {
      self.aspectRatio = imageAspectRatio
    }

    // Character aspect ratio compensation - characters are typically taller than wide
    let characterAspectRatio = 0.5  // Adjust this value based on your font
    let targetHeight = Int(Double(targetWidth) / imageAspectRatio * characterAspectRatio)

    // Resize image
    guard let resizedImage = resizeImage(cgImage: cgImage, width: targetWidth, height: targetHeight)
    else {
      return "Error resizing image"
    }

    // Convert to grayscale and extract pixel data
    guard let pixelData = getGrayscalePixelData(from: resizedImage) else {
      return "Error processing image data"
    }

    // Convert pixels to ASCII with improved character mapping
    var asciiString = ""
    for y in 0..<targetHeight {
      for x in 0..<targetWidth {
        let pixelIndex = y * targetWidth + x
        let brightness = pixelData[pixelIndex]

        // Improved brightness mapping with gamma correction
        let gammaCorrected = pow(brightness, 0.7)  // Adjust gamma for better contrast
        let charIndex = Int(gammaCorrected * Double(asciiChars.count - 1))
        let char = asciiChars[asciiChars.index(asciiChars.startIndex, offsetBy: charIndex)]
        asciiString.append(char)
      }
      asciiString.append("\n")
    }

    return asciiString
  }

  // Resize CGImage to target dimensions
  private func resizeImage(cgImage: CGImage, width: Int, height: Int) -> CGImage? {
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )

    context?.interpolationQuality = .high
    context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    return context?.makeImage()
  }

  // Extract grayscale pixel data from image
  private func getGrayscalePixelData(from cgImage: CGImage) -> [Double]? {
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8

    var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

    let context = CGContext(
      data: &pixelData,
      width: width,
      height: height,
      bitsPerComponent: bitsPerComponent,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )

    context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Convert RGBA to grayscale brightness values
    var grayscaleData: [Double] = []
    for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
      let r = Double(pixelData[i])
      let g = Double(pixelData[i + 1])
      let b = Double(pixelData[i + 2])

      // Calculate luminance using standard weights
      let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
      grayscaleData.append(brightness)
    }

    return grayscaleData
  }

  // Get frame delay for proper timing
  func getFrameDelay(at index: Int) -> Double {
    guard let gifSource = gifSource,
      let properties = CGImageSourceCopyPropertiesAtIndex(gifSource, index, nil) as? [String: Any],
      let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any]
    else {
      return 0.1  // Default delay
    }

    if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
      return max(delayTime, 0.1)  // Minimum delay of 0.1 seconds
    }

    return 0.1
  }

  deinit {
    stopConversion()
  }
}

import AVFoundation  // Add this import
import CoreImage
import Foundation
import ImageIO
import SwiftUI
import UIKit

class Ascii: ObservableObject {
  @Published var currentFrame: String = ""
  @Published var isProcessing: Bool = false
  @Published var aspectRatio: Double = 1.0
  @Published var targetWidth: Int = 80

  private let frameRate = 0.08  // Increased frame rate for smoother playback
  private let asciiChars = "@#%$*+=-:. ".reversed()

  private var gifSource: CGImageSource?
  private var videoAsset: AVAsset?
  private var precomputedVideoFrames: [String] = []  // Cache ASCII frames
  private var videoDuration: CMTime = .zero
  
  public var frameCount: Int = 0
  public var currentFrameIndex: Int
  private var timer: Timer?
  private var isPrecomputing: Bool = false

  init(targetWidth: Int = 80, frame: Int? = nil) {
    self.targetWidth = targetWidth
    self.currentFrameIndex = frame ?? 0
  }

  func loadGIF(from url: URL) {
    // Clear any existing video data
    clearVideoData()
    
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
    // Clear any existing video data
    clearVideoData()
    
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
      print("Failed to create image source from data")
      return
    }

    self.gifSource = imageSource
    self.frameCount = CGImageSourceGetCount(imageSource)
    self.currentFrameIndex = 0

    print("Loaded GIF with \(frameCount) frames")
  }

  // Optimized function to load MP4 videos
  func loadVideo(url: URL) {
    // Clear any existing GIF data
    clearGIFData()
    
    let asset = AVAsset(url: url)
    self.videoAsset = asset
    
    // Check if the asset has video tracks
    guard asset.tracks(withMediaType: .video).count > 0 else {
      print("No video tracks found in the asset")
      return
    }
    
    // Get video duration
    self.videoDuration = asset.duration
    let durationInSeconds = CMTimeGetSeconds(videoDuration)
    
    // Reduce target FPS for better performance but still smooth
    let targetFPS = 15.0 // Increased from 10 for smoother playback
    let frameInterval = 1.0 / targetFPS
    
    // Calculate total frames
    let totalFrames = Int(durationInSeconds * targetFPS)
    self.frameCount = totalFrames
    self.currentFrameIndex = 0
    
    // Get aspect ratio from video
    if let videoTrack = asset.tracks(withMediaType: .video).first {
      let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
      let videoAspectRatio = Double(abs(size.width)) / Double(abs(size.height))
      DispatchQueue.main.async {
        self.aspectRatio = videoAspectRatio
      }
    }
    
    print("Loaded video with \(frameCount) frames at \(targetFPS) FPS")
    
    // Start precomputing frames in background
    precomputeVideoFrames(asset: asset, targetFPS: targetFPS, durationInSeconds: durationInSeconds)
  }
  
  private func precomputeVideoFrames(asset: AVAsset, targetFPS: Double, durationInSeconds: Double) {
    guard !isPrecomputing else { return }
    isPrecomputing = true
    
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      
      let imageGenerator = AVAssetImageGenerator(asset: asset)
      imageGenerator.appliesPreferredTrackTransform = true
      imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
      imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
      
      var frames: [String] = []
      let frameInterval = 1.0 / targetFPS
      
      var currentTime = 0.0
      while currentTime < durationInSeconds {
        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        
        do {
          let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
          let asciiString = self.convertImageToASCII(cgImage: cgImage)
          frames.append(asciiString)
        } catch {
          // If frame generation fails, use empty frame or previous frame
          let emptyFrame = String(repeating: " ", count: self.targetWidth * 20) // Fallback
          frames.append(emptyFrame)
          print("Warning: Could not generate frame at time \(currentTime): \(error.localizedDescription)")
        }
        
        currentTime += frameInterval
      }
      
      DispatchQueue.main.async {
        self.precomputedVideoFrames = frames
        self.frameCount = frames.count
        self.isPrecomputing = false
        print("Precomputed \(frames.count) video frames")
      }
    }
  }
  
  private func clearGIFData() {
    gifSource = nil
  }
  
  private func clearVideoData() {
    videoAsset = nil
    precomputedVideoFrames = []
    videoDuration = .zero
    isPrecomputing = false
  }

  public func calculateOptimalFontSize(for size: CGSize) -> CGFloat {
    let baseSize: CGFloat = min(size.width / CGFloat(self.targetWidth) * 0.8, 12)
    return max(baseSize, 4)  // Minimum font size of 4
  }

  // Start real-time ASCII conversion
  func startConversion(_ frameIndex: Int? = nil) {
    guard (gifSource != nil || videoAsset != nil), frameCount > 0 else {
      print(
        "No GIF or video loaded - gifSource: \(gifSource != nil), videoAsset: \(videoAsset != nil), frameCount: \(frameCount)"
      )
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

  // Optimized frame processing
  private func processNextFrame(fixedIndex: Int? = nil) {
    let frameIndex: Int
    if let fixedIndex = fixedIndex {
      frameIndex = min(fixedIndex, frameCount - 1)
    } else {
      frameIndex = currentFrameIndex % frameCount
    }
    
    // Handle GIF frames
    if let gifSource = gifSource {
      if let cgImage = CGImageSourceCreateImageAtIndex(gifSource, frameIndex, nil) {
        let asciiString = convertImageToASCII(cgImage: cgImage)
        DispatchQueue.main.async {
          self.currentFrame = asciiString
        }
      }
    }
    // Handle precomputed video frames
    else if !precomputedVideoFrames.isEmpty && frameIndex < precomputedVideoFrames.count {
      let asciiString = precomputedVideoFrames[frameIndex]
      DispatchQueue.main.async {
        self.currentFrame = asciiString
      }
    }
    // Fallback: show loading message if frames aren't ready yet
    else if videoAsset != nil && isPrecomputing {
      DispatchQueue.main.async {
        self.currentFrame = "Loading video frames..."
      }
    }

    // Only increment for sequential playback
    if fixedIndex == nil {
      currentFrameIndex = (currentFrameIndex + 1) % frameCount
    }
  }

  // Core ASCII conversion function with improved aspect ratio handling
  private func convertImageToASCII(cgImage: CGImage) -> String {
    let originalWidth = cgImage.width
    let originalHeight = cgImage.height

    // Calculate and store aspect ratio for UI (only update if not already set)
    let imageAspectRatio = Double(originalWidth) / Double(originalHeight)
    if aspectRatio == 1.0 {
      DispatchQueue.main.async {
        self.aspectRatio = imageAspectRatio
      }
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
        let gammaCorrected = pow(brightness, 0.5)  // Adjust gamma for better contrast
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

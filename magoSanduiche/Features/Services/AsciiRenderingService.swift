////
////  AsciiRenderingService.swift
////  magoSanduiche
////
////  Created by Enzo Enrico on 06/12/25.
////

//import AVFoundation
//import CoreImage
//import SwiftUI

//@available(*, deprecated, message: "do not use it yet")
//class Ascii: ObservableObject {
//    @Published var currentFrame: String = ""
//    @Published var isPlaying: Bool = false
//    @Published var aspectRatio: Double = 1.0

//    var targetWidth: Int
//    var frameCount: Int = 0
//    var currentFrameIndex: Int = 0

//    private let frameRate = 0.08
//    private let asciiChars = "  .*░▒▓█"

//    private var videoFrames: [String] = []
//    private var timer: Timer?

//    init(targetWidth: Int = 80) {
//        self.targetWidth = targetWidth
//    }

//    // MARK: - Image Conversion

//    func convertToASCII(image: UIImage) -> String {
//        guard let cgImage = image.cgImage else { return "" }
//        return convertImageToASCII(cgImage: cgImage)
//    }

//    // MARK: - Video Loading & Playback

//    func loadVideo(url: URL) {
//        stopPlayback()
//        videoFrames = []

//        let asset = AVAsset(url: url)
//        let duration = CMTimeGetSeconds(asset.duration)
//        let targetFPS = 15.0

//        frameCount = Int(duration * targetFPS)
//        currentFrameIndex = 0

//        precomputeVideoFrames(asset: asset, targetFPS: targetFPS, duration: duration)
//    }

//    func startPlayback() {
//        guard !videoFrames.isEmpty else { return }

//        isPlaying = true
//        timer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { [weak self] _ in
//            self?.displayNextFrame()
//        }
//    }

//    func stopPlayback() {
//        isPlaying = false
//        timer?.invalidate()
//        timer = nil
//    }

//    // MARK: - Private

//    private func precomputeVideoFrames(asset: AVAsset, targetFPS: Double, duration: Double) {
//        Task.detached { [weak self] in
//            guard let self else { return }

//            let generator = AVAssetImageGenerator(asset: asset)
//            generator.appliesPreferredTrackTransform = true
//            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
//            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

//            let frameInterval = 1.0 / targetFPS
//            var currentTime = 0.0
//            var frames: [String] = []

//            while currentTime < duration {
//                let time = CMTime(seconds: currentTime, preferredTimescale: 600)

//                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
//                    frames.append(self.convertImageToASCII(cgImage: cgImage))
//                }

//                currentTime += frameInterval
//            }

//            await MainActor.run {
//                self.videoFrames = frames
//                self.frameCount = frames.count
//            }
//        }
//    }

//    private func displayNextFrame() {
//        guard !videoFrames.isEmpty else { return }

//        currentFrame = videoFrames[currentFrameIndex]
//        currentFrameIndex = (currentFrameIndex + 1) % frameCount
//    }

//    private func convertImageToASCII(cgImage: CGImage) -> String {
//        let originalWidth = cgImage.width
//        let originalHeight = cgImage.height
//        let imageAspectRatio = Double(originalWidth) / Double(originalHeight)

//        if aspectRatio == 1.0 {
//            aspectRatio = imageAspectRatio
//        }

//        // Characters are taller than wide, compensate
//        let charAspectRatio = 0.5
//        let targetHeight = Int(Double(targetWidth) / imageAspectRatio * charAspectRatio)

//        guard let resized = resizeImage(cgImage: cgImage, width: targetWidth, height: targetHeight),
//              let pixels = getGrayscalePixels(from: resized)
//        else {
//            return ""
//        }

//        var result = ""
//        for y in 0..<targetHeight {
//            for x in 0..<targetWidth {
//                let brightness = pixels[y * targetWidth + x]
//                let corrected = pow(brightness, 0.5)
//                let charIndex = Int(corrected * Double(asciiChars.count - 1))
//                let char = asciiChars[asciiChars.index(asciiChars.startIndex, offsetBy: charIndex)]
//                result.append(char)
//            }
//            result.append("\n")
//        }

//        return result
//    }

//    private func resizeImage(cgImage: CGImage, width: Int, height: Int) -> CGImage? {
//        let context = CGContext(
//            data: nil,
//            width: width,
//            height: height,
//            bitsPerComponent: 8,
//            bytesPerRow: 0,
//            space: CGColorSpaceCreateDeviceRGB(),
//            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
//        )

//        context?.interpolationQuality = .high
//        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

//        return context?.makeImage()
//    }

//    private func getGrayscalePixels(from cgImage: CGImage) -> [Double]? {
//        let width = cgImage.width
//        let height = cgImage.height
//        let bytesPerPixel = 4
//        let bytesPerRow = bytesPerPixel * width

//        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

//        let context = CGContext(
//            data: &pixelData,
//            width: width,
//            height: height,
//            bitsPerComponent: 8,
//            bytesPerRow: bytesPerRow,
//            space: CGColorSpaceCreateDeviceRGB(),
//            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
//        )

//        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

//        var grayscale: [Double] = []
//        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
//            let r = Double(pixelData[i])
//            let g = Double(pixelData[i + 1])
//            let b = Double(pixelData[i + 2])
//            let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
//            grayscale.append(brightness)
//        }

//        return grayscale
//    }

//    deinit {
//        stopPlayback()
//    }
//}


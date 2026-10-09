//
//  GameViewModel+Vision.swift
//  magoSanduiche
//

import CoreGraphics
import Foundation
import ImagePlayground

#if canImport(UIKit)
    import UIKit
#endif

extension GameViewModel {
    func handleVisionAfterTurn(visualPrompt: String?, prompt: PlayerPromptID, turnID: String) async {
        guard hasSubmittedPlayerTurn else { return }
        guard let visualPrompt else { return }

        if dungeonMaster.illustratesWithSystemSheet {
            presentImagePlayground(prompt: visualPrompt, turnID: turnID)
            return
        }

        let requestID = UUID()
        latestVisionRequestID = requestID
        beginCollapsedGeneration()
        defer { finishCollapsedGeneration(requestID) }
        #if canImport(UIKit)
            let backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "scene_archive") {}
            defer {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
        #endif

        do {
            let image = try await dungeonMaster.illustrate(
                visualPrompt: visualPrompt,
                analyticsContext: aiContext(turnID: turnID),
                progress: visionProgress(for: requestID)
            )
            await keepSceneEvenIfSuperseded(image, for: prompt)
            guard latestVisionRequestID == requestID else { return }
            showCurrentScene(image, for: prompt)
        } catch {
            // Keep the current frame. The preview stays closed until a scene arrives.
        }
    }

    private func keepSceneEvenIfSuperseded(_ image: SceneImage, for prompt: PlayerPromptID) async {
        guard await sceneArchive?.keep(image, for: prompt) == true else { return }
        storedSceneRevision += 1
    }

    private func showCurrentScene(_ image: SceneImage, for prompt: PlayerPromptID) {
        visionDisplayMode = .scene(SceneImage(cgImage: image.cgImage, id: prompt.entryID))
        coordinator?.revealVisionIfCollapsed()
    }

    func recallScene(_ prompt: PlayerPromptID) {
        if visionDisplayMode.recalledPrompt == prompt {
            coordinator?.revealVisionIfCollapsed()
            return
        }
        guard let archive = sceneArchive else { return }
        guard let image = archive.image(for: prompt) else {
            storedSceneRevision += 1
            return
        }
        visionDisplayMode = .recalled(prompt, image)
        coordinator?.revealVisionIfCollapsed()
    }

    func presentImagePlayground(prompt: String, turnID: String? = nil) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var extra: [String: Any] = [
            "prompt": trimmed,
            "prompt_length": trimmed.count,
            "generator": "image_playground",
        ]
        if let turnID {
            extra["turn_id"] = turnID
        }
        guard SceneImageGeneration.isLocked == false, canPresentImagePlayground else {
            extra["error_kind"] = SceneImageGeneration.isLocked ? "locked" : "unavailable"
            log("image_generation_prompt", level: .warn, extra: extra)
            return
        }
        log("image_generation_prompt", extra: extra)
        imagePlaygroundConcept = trimmed
        coordinator?.collapseVisionIfExpanded()
        isImagePlaygroundPresented = true
    }

    func acceptPlaygroundImage(at url: URL) {
        isImagePlaygroundPresented = false
        guard let cgImage = try? SceneImageLoader.cgImage(at: url) else { return }
        visionDisplayMode = .scene(SceneImage(cgImage: SceneFrame.widescreen(cgImage)))
        coordinator?.revealVisionIfCollapsed()
    }

    func cancelImagePlayground() {
        isImagePlaygroundPresented = false
    }

    func consumeDebugPlaygroundRequest() {
        #if DEBUG
            guard let prompt = queuedDebugPlaygroundPrompt else { return }
            queuedDebugPlaygroundPrompt = nil
            presentImagePlayground(prompt: prompt)
        #endif
    }

    private var canPresentImagePlayground: Bool {
        #if DEBUG
            if let imagePlaygroundAvailabilityOverride {
                return imagePlaygroundAvailabilityOverride
            }
        #endif
        return ImagePlaygroundViewController.isAvailable
    }

    var visionGenerationPercent: Int? {
        guard let visionGenerationProgress else { return nil }
        return Int((min(max(visionGenerationProgress, 0), 1) * 100).rounded())
    }

    private func beginCollapsedGeneration() {
        visionMediaLoading = true
        visionGenerationProgress = 0
        coordinator?.collapseVisionIfExpanded()
    }

    private func finishCollapsedGeneration(_ requestID: UUID) {
        guard latestVisionRequestID == requestID else { return }
        visionMediaLoading = false
        visionGenerationProgress = nil
    }

    private func visionProgress(for requestID: UUID) -> SceneIllustrationProgress {
        let relay = VisionProgressRelay { fraction in
            self.applyVisionProgress(fraction, for: requestID)
        }
        return SceneIllustrationProgress { relay.update($0) }
    }

    private func applyVisionProgress(_ fraction: Double, for requestID: UUID) {
        guard latestVisionRequestID == requestID, visionMediaLoading else { return }
        visionGenerationProgress = min(1, max(0, fraction))
    }
}

private nonisolated final class VisionProgressRelay: @unchecked Sendable {
    private let apply: @MainActor (Double) -> Void

    init(_ apply: @escaping @MainActor (Double) -> Void) {
        self.apply = apply
    }

    func update(_ fraction: Double) {
        let fraction = min(1, max(0, fraction))
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                apply(fraction)
            }
        } else {
            Task { @MainActor in
                apply(fraction)
            }
        }
    }
}

#if DEBUG
    struct DebugImageGeneration: Sendable {
        var message: String
        var didProduceImage: Bool
        var shouldDismiss: Bool
    }

    extension GameViewModel {
        func illustrateFromDebug(visualPrompt: String) async -> DebugImageGeneration {
            let trimmed = visualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return DebugImageGeneration(
                    message: String(localized: "nan_debug_ai_tools_image_empty"),
                    didProduceImage: false,
                    shouldDismiss: false
                )
            }
            let caption = SceneCaption.compose(
                SceneDirection(poseOrAction: "stands in the room, staff in hand", location: trimmed),
                memory: &sceneMemory
            )

            if dungeonMaster.illustratesWithSystemSheet {
                guard SceneImageGeneration.isLocked == false else {
                    return DebugImageGeneration(
                        message: String(localized: "nan_debug_ai_tools_image_locked"),
                        didProduceImage: false,
                        shouldDismiss: false
                    )
                }
                guard canPresentImagePlayground else {
                    return DebugImageGeneration(
                        message: String(localized: "nan_debug_ai_tools_image_unavailable"),
                        didProduceImage: false,
                        shouldDismiss: false
                    )
                }
                queuedDebugPlaygroundPrompt = caption
                return DebugImageGeneration(
                    message: String(localized: "nan_debug_ai_tools_image_sheet"),
                    didProduceImage: false,
                    shouldDismiss: true
                )
            }

            let requestID = UUID()
            latestVisionRequestID = requestID
            beginCollapsedGeneration()
            defer { finishCollapsedGeneration(requestID) }

            do {
                let image = try await dungeonMaster.illustrate(
                    visualPrompt: caption,
                    analyticsContext: aiContext(turnID: "debug-image"),
                    progress: visionProgress(for: requestID)
                )
                visionDisplayMode = .scene(image)
                coordinator?.revealVisionIfCollapsed()
                let size = "\(image.cgImage.width)x\(image.cgImage.height)"
                return DebugImageGeneration(
                    message: "\(String(localized: "nan_debug_ai_tools_image_ready")) \(size)",
                    didProduceImage: true,
                    shouldDismiss: false
                )
            } catch {
                return DebugImageGeneration(
                    message: error.localizedDescription,
                    didProduceImage: false,
                    shouldDismiss: false
                )
            }
        }
    }
#endif

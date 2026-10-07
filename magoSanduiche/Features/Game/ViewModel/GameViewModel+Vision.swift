//
//  GameViewModel+Vision.swift
//  magoSanduiche
//

import CoreGraphics
import Foundation
import ImagePlayground

extension GameViewModel {
    func handleVisionAfterTurn(visualPrompt: String?, turnID: String) async {
        guard hasSubmittedPlayerTurn else { return }
        guard let visualPrompt else { return }

        if dungeonMaster.illustratesWithSystemSheet {
            presentImagePlayground(prompt: visualPrompt)
            return
        }

        visionMediaLoading = true
        coordinator?.revealVisionIfCollapsed()
        defer { visionMediaLoading = false }

        do {
            let image = try await dungeonMaster.illustrate(
                visualPrompt: visualPrompt,
                analyticsContext: aiContext(turnID: turnID)
            )
            visionDisplayMode = .scene(image)
            coordinator?.revealVisionIfCollapsed()
        } catch {
            // Keep the current frame. A failed illustration should not hide the panel.
        }
    }

    func presentImagePlayground(prompt: String) {
        guard SceneImageGeneration.isLocked == false else { return }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canPresentImagePlayground else { return }
        imagePlaygroundConcept = trimmed
        coordinator?.revealVisionIfCollapsed()
        isImagePlaygroundPresented = true
    }

    func acceptPlaygroundImage(at url: URL) {
        isImagePlaygroundPresented = false
        guard let cgImage = try? SceneImageLoader.cgImage(at: url) else { return }
        visionDisplayMode = .scene(SceneImage(cgImage: cgImage))
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
                queuedDebugPlaygroundPrompt = trimmed
                return DebugImageGeneration(
                    message: String(localized: "nan_debug_ai_tools_image_sheet"),
                    didProduceImage: false,
                    shouldDismiss: true
                )
            }

            visionMediaLoading = true
            coordinator?.revealVisionIfCollapsed()
            defer { visionMediaLoading = false }

            do {
                let image = try await dungeonMaster.illustrate(
                    visualPrompt: trimmed,
                    analyticsContext: aiContext(turnID: "debug-image")
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

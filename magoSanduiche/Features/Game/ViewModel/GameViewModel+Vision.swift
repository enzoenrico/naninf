//
//  GameViewModel+Vision.swift
//  magoSanduiche
//

import Foundation

extension GameViewModel {
    func handleVisionAfterTurn(visualPrompt: String?, turnID: String) async {
        guard hasSubmittedPlayerTurn else { return }
        guard let visualPrompt else {
            clearPostIntroVisionMedia()
            return
        }

        visionDisplayMode = .introStatic
        coordinator?.collapseVisionIfExpanded()
        visionMediaLoading = true
        defer { visionMediaLoading = false }

        do {
            guard
                let resource = try await dungeonMaster?.generateSceneMedia(
                    visualPrompt: visualPrompt,
                    analyticsContext: aiContext(turnID: turnID)
                )
            else {
                clearPostIntroVisionMedia()
                return
            }
            visionDisplayMode = .remote(resource)
        } catch {
            clearPostIntroVisionMedia()
        }
    }

    func clearPostIntroVisionMedia() {
        visionDisplayMode = .introStatic
        coordinator?.collapseVisionIfExpanded()
    }
}

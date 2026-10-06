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
            let image = try await dungeonMaster.illustrate(
                visualPrompt: visualPrompt,
                analyticsContext: aiContext(turnID: turnID)
            )
            visionDisplayMode = .scene(image)
        } catch {
            clearPostIntroVisionMedia()
        }
    }

    func clearPostIntroVisionMedia() {
        visionDisplayMode = .introStatic
        coordinator?.collapseVisionIfExpanded()
    }
}

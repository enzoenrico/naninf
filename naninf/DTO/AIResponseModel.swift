//
//  AIModel.swift
//  naninf
//
//  Created by Enzo Enrico on 03/12/25.
//

import Foundation
import CoreGraphics

// handles both text and images
enum AIResponse {
    case text(String)
    case image(CGImage)
}

struct AIResponseModel {
    let incomingPrompt: String
    let response: AIResponse
}


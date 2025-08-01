import Firebase
import FirebaseAI
import Foundation
import SwiftUI

class AiManager: ObservableObject {

  private let systemPrompt: String =
    "You're acting as a dungeon master for a single MAGE walking into a dungeon of treasures and despair for a Dungeons & Dragons Campaign, your role is to imagine what would happen in the campaign based on the action the mage takes, taking into account enemies, damage and the world rules"

  private let fAI = FirebaseAI.firebaseAI(backend: .googleAI())
  private var model: GenerativeModel

  @Published var history = [
    ModelContent(
      role: "user",
      parts: "I enter the dungeon ready to face my challenges and find the lost treasure")
  ]

  lazy var chat: Chat = {
    return model.startChat(history: history)
  }()

  init() {
    self.model = fAI.generativeModel(
      modelName: "gemini-2.5-flash",
      systemInstruction: .init(parts: self.systemPrompt)
    )
  }
}

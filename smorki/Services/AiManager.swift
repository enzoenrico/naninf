import FalClient
import Firebase
import FirebaseAI
import Foundation
import SwiftUI

class AiManager: ObservableObject {
  private let systemPrompt: String =
    """
    You are an expert Dungeon Master AI, weaving a solo text-based Dungeons & Dragons campaign for a single player. Your purpose is to create a living, breathing dungeon full of rich narrative, dynamic challenges, and meaningful character progression.
    You are merely a narrator and guide, not a player. The player is a mage, and you will refer to them as "the mage" in your responses.
    Your Core Directives:
    Narrate a Persistent World:
    Format: Your narrative responses will be broken into paragraphs, each preceded by a > character to create a sense of progression and readability.
    Sensory Detail: Describe what the mage sees, hears, smells, and feels. The atmosphere is just as important as the events.
    Memory and Consequence: You will remember all previous actions and choices. A door kicked down will remain broken. An enemy spared may return later. The chat history is your memory.
    Dynamic Events: The dungeon is not static. Creatures move, patrols shift, and environmental effects can change over time. My actions (or inaction) will directly influence this living environment.
    Guide the Adventure:
    Player Agency: Every response will end with the clear and open-ended question: "What do you do?"
    Suggested Actions: Following the question, you will provide three distinct and varied suggestions for actions I could take. These should be creative and relevant to the situation, often reflecting different approaches (e.g., aggressive, stealthy, intellectual).
    Implicit Rules: You will adjudicate the outcomes of my actions based on narrative logic, the character's specialty, and the established world rules. For actions with a chance of failure (disarming a complex trap, casting a massive spell), you can describe the risk and the potential outcomes. Use LaTeX for dice rolls, stats, or spell effects when it adds to the immersion, like describing damage as dealing $1d6+2$ fire damage.
    """

  private let fAI = FirebaseAI.firebaseAI(backend: .googleAI())
  private var model: GenerativeModel
  private var falModel = FalClient.withCredentials(
    .keyPair("e502344a-c850-4705-8300-e41d1abee65e:87570f51674fa14cca412790d58f6cd1")
  )

  @Published var history = [
    ModelContent(
      role: "user",
      parts: "I enter the dungeon ready to face my challenges and find the lost treasure")
  ]

  @Published var generatedVideoURL: String?
  @Published var isGeneratingVideo = false

  lazy var chat: Chat = {
    return model.startChat(history: history)
  }()

  init() {
    self.model = fAI.generativeModel(
      modelName: "gemini-2.5-flash",
      systemInstruction: .init(parts: self.systemPrompt)
    )
  }

  public func generateVideo(_ prompt: String) async {
    DispatchQueue.main.async {
      self.isGeneratingVideo = true
      self.generatedVideoURL = nil
    }

    do {
      let result = try await falModel.subscribe(
        to: "fal-ai/wan/v2.2-a14b/text-to-video/turbo",
        input: [
          "prompt": Payload.string(prompt),
          "resolution": Payload.string("480p"),
          "fps": Payload.int(24),
        ]
      ) { update in
        if case let .inProgress(logs) = update {
          print("Generation progress: \(logs)")
        }
      }

      print("Raw result: \(result)")


      DispatchQueue.main.async {
        self.isGeneratingVideo = false
        self.generatedVideoURL = result["video"].stringValue
      }

    } catch {
      print("Error generating video: \(error.localizedDescription)")
      DispatchQueue.main.async {
        self.isGeneratingVideo = false
      }
    }
  }

  // Helper function to extract string from Payload
  private func extractString(from payload: Payload) -> String? {
    if case let .string(value) = payload {
      return value
    }
    return nil
  }

  // Helper function to extract int from Payload
  private func extractInt(from payload: Payload) -> Int? {
    if case let .int(value) = payload {
      return value
    }
    return nil
  }

  // Enhanced extraction method that handles Payload types
  private func extractVideoURL(from result: [String: Payload]) -> String? {
    // Try the main video.url path first (based on your console output)
    if let videoPayload = result["video"] as? [String: Payload],
      let urlPayload = videoPayload["url"],
      case let .string(url) = urlPayload
    {
      return url
    }

    // Try alternative structures
    let possibleKeys = ["video", "output", "url", "file_url", "video_url"]

    for key in possibleKeys {
      if let payload = result[key] {
        // If it's directly a string payload
        if case let .string(url) = payload {
          return url
        }
        // If it's a nested dictionary
        else if case let .dict(nestedDict) = payload,
          let urlPayload = nestedDict["url"],
          case let .string(url) = urlPayload
        {
          return url
        }
      }
    }

    return nil
  }
}

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
    Always push encounters with enemies, make exciting battles happen where the enemies are strong and intelligent and always try to kill the player.
    """

  private let generatorPrompt: String = """
    Based on the following structure, create a visual narrative according to the provided context, building upon the existing history and universe to create detailed, cinematic and immersive descriptions of the provided actions keeping the structure under 500 characters.
    Focus on the content provided by the user_input as the main action portraied in the immagined scene
    Structure: 
        {
        "subject": "An elderly, powerful human wizard with a long white beard, wearing ornate blue and gold robes and holding a gnarled wooden staff topped with a glowing crystal.",
        "context": "The context which the action takes place in, including the environment and any relevant background details.",
        "action": "The action being performed by the subject, described in a cinematic and immersive manner.",
        "style": "Epic high fantasy, Dungeons and Dragons (D&D) concept art style, hyper-detailed, cinematic, 8K, Unreal Engine 5 render.",
        "cameraMotion": "The type of camera motion that captures the action, such as a slow dolly shot, sweeping crane shot, etc.",
        "composition": "The camera composition, such as wide shot, close-up, following the rule of thirds, etc.",
        "ambiance": "The overall mood and atmosphere of the scene, including lighting, color tones, and any special effects like fog or magical elements."
        }

    Example: {
    "system_response": " The ancient stone doors creak shut behind you with a sound that reverberates through the very foundations of the earth, plunging the small antechamber into near absolute darkness. A faint, greenish bioluminescent moss clings to patches of the rough-hen walls, offering only the barest outlines of your surroundings. The air is heavy, thick with the scent of damp earth, stagnant water, and a faint, acrid tang that prickles your nose. A persistent drip-drip-drip echoes from somewhere deeper within, broken only by the soft scuttling of unseen creatures in the shadowy corners. The floor beneath your boots is uneven, slick with condensation. > Ahead, the narrow, low-ceilinged passage you find yourself in seems to widen after about ten paces, opening into what feels like a much larger, cavernous space. Only the blackest void greets your eyes beyond the meager light of the moss. This is it. The entrance to the Sunken Citadel of Xylos, a place whispered to hold forgotten treasures and unspeakable horrors.",
    "user_input": "I cast a light spell",
    }

    Output:

    An epic high fantasy D&D concept art scene, hyper-detailed in cinematic 8K, rendered in Unreal Engine 5.
    A slow dolly shot moves forward from behind the shoulder of an elderly, powerful human wizard as he cautiously enters the dark, foreboding Sunken Citadel of Xylos. In a wide shot that emphasizes the grand, cavernous scale of the dungeon against the solitary figure, we see his ornate blue and gold robes. A long white beard rests on his chest. He holds a gnarled wooden staff aloft, and its crystal topper pulses with a warm, magical glow. This light cuts through the mysterious, cool blue tones of the darkness, casting dynamic shadows and illuminating the volumetric fog swirling at his feet. The air is thick with an eerie silence, broken only by the distant drip of water as he moves deeper into the maw of the dungeon.
    """

  private let fAI = FirebaseAI.firebaseAI(backend: .googleAI())
  private var model: GenerativeModel
  private var generatorModel: GenerativeModel
  private var falModel = FalClient.withCredentials(
    .keyPair("e502344a-c850-4705-8300-e41d1abee65e:87570f51674fa14cca412790d58f6cd1")
  )

  @Published var history = [
    ModelContent()
  ]

  @Published var generatedVideoURL: String?
  @Published var isGeneratingVideo = false

  lazy var chat: Chat = {
    return model.startChat(history: history)
  }()

  lazy var generatorChat: Chat = {
    return generatorModel.startChat()
  }()

  init() {
    self.model = fAI.generativeModel(
      modelName: "gemini-2.5-flash",
      systemInstruction: .init(parts: self.systemPrompt)
    )
    self.generatorModel = fAI.generativeModel(
      modelName: "gemini-2.5-flash-lite",
      systemInstruction: .init(parts: self.generatorPrompt)
    )
  }

  public func generateVideo(_ prompt: String) async -> URL? {
    do {
      let result = try await falModel.subscribe(
        to: "fal-ai/wan/v2.2-a14b/text-to-video",
        // to: "fal-ai/wan-t2v",
        // to: "fal-ai/pika/v2/turbo/text-to-video",
        input: [
          "prompt": Payload.string(prompt),
          "resolution": Payload.string("480p"),
          "enable_safety_checker": Payload.bool(false),
          // "resolution": Payload.string("720p"),
          // "turbo_mode": Payload.bool(true),
        ]
      ) { update in
        if case let .inProgress(logs) = update {
          print("Generation progress: \(logs)")
        }
        print(update.logs)
      }

      print("Raw result: \(result)")

      DispatchQueue.main.async {
        self.generatedVideoURL = result["video"]["url"].stringValue
        print(self.generatedVideoURL)
      }

      return URL(string: self.generatedVideoURL ?? "")

    } catch {
      print("Error generating video: \(error.localizedDescription)")
      DispatchQueue.main.async {
        self.isGeneratingVideo = false
      }
      return URL(string: "")
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

}

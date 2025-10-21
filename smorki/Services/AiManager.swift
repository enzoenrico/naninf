import FalClient
import Firebase
import FirebaseAI
import Foundation
import SwiftUI

class AiManager: ObservableObject {
  private var negativeVideoPrompt: String = Prompts.negativePrompt.rawValue

  private var systemPrompt: String = Prompts.storyPrompt.rawValue

  private var generatorPrompt: String = Prompts.imagePrompt.rawValue

  private let fAI = FirebaseAI.firebaseAI(backend: .googleAI())
  private var model: GenerativeModel
  private var generatorModel: GenerativeModel
  private var imageModel: GenerativeModel

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
    self.imageModel = fAI.generativeModel(
      modelName: "gemini-2.0-flash-preview-image-generation",
      generationConfig: GenerationConfig(responseModalities: [.text, .image])
    )
  }

  public func generateImage(_ prompt: String) async -> UIImage? {
    print("Image prompt")
    print(prompt == "" ? "No return" : prompt)
    do {
      let gen_return = try await self.imageModel.generateContent(prompt)
      guard let data = gen_return.inlineDataParts.first,
        let img = UIImage(data: data.data)
      else {
        print("Generated image but couldn't get it's data")
        return nil
      }
      return img
    } catch {
      print("Caught error in generateImage")
      print(error.localizedDescription)
      return nil
    }
  }

}


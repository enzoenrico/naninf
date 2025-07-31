import Firebase
import FirebaseAI
import Foundation
import SwiftUI

class AiManager: ObservableObject {
    
    private let fAI = FirebaseAI.firebaseAI(backend: .googleAI())
    var ai: GenerativeModel {
      return fAI.generativeModel(modelName: "gemini-2.5-flash")
    }
    
    
}

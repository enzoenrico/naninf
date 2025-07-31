import SwiftUI

struct WaveRenderer: TextRenderer {
  var strength: Double
  var frequency: Double

  var animatableData: Double {
    get { strength }
    set { strength = newValue }
  }

  func draw(layout: Text.Layout, in context: inout GraphicsContext) {
    for line in layout {
      for run in line {
        for (index, glyph) in run.enumerated() {
          let yOffset = strength * sin(Double(index) * frequency)
          var copy = context

          copy.translateBy(x: 0, y: yOffset)
          copy.draw(glyph, options: .disablesSubpixelQuantization)
        }
      }
    }
  }
}

struct CharacterReplace: TextRenderer {
  let letters = "abcdefghijklmnopqrstuvwxyz.:|$*&@!"
  var glitchIntensity: Double = 0.3
  var time: Double = 0.0 // Add this for animation
  
  var animatableData: Double {
    get { time }
    set { time = newValue }
  }
  
  func draw(layout: Text.Layout, in context: inout GraphicsContext) {
    for line in layout {
      for run in line {
        for (index, glyph) in run.enumerated() {
          var copy = context
          
          // Use time and position to create deterministic but changing glitches
          let seed = sin(time * 10 + Double(index) * 0.5) 
          let shouldGlitch = abs(seed) > (1.0 - glitchIntensity)
          
          if shouldGlitch {
            let randomIndex = Int(abs(seed * 1000)) % letters.count
            let replacementChar = String(letters[letters.index(letters.startIndex, offsetBy: randomIndex)])
            
            let glitchGlyph = Text(replacementChar)
              .foregroundColor(.red)
            
          } else {
            copy.draw(glyph, options: .disablesSubpixelQuantization)
          }
        }
      }
    }
  }
}
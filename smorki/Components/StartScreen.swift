import SwiftUI

struct StartScreen: View {
  @State private var characters: [RandomCharacter] = []
  @State private var timer: Timer?
  @State private var timeInterval: Double = 0.1
  @State private var charactersPerSpawn: Int = 1
  @State private var currentRow: Int = 0
  @State private var currentColumn: Int = 0
  @State private var maxColumns: Int = 0
  @State private var maxRows: Int = 0

  private let possibleCharacters =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"

  private let fontSize: CGFloat = 16
  private let lineHeight: CGFloat = 20
  private let characterWidth: CGFloat = 10

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.black
          .ignoresSafeArea()

        ForEach(characters) { character in
          Text(String(character.char))
            .foregroundColor(.green)
            .position(x: character.x, y: character.y)
            .opacity(character.opacity)
            .animation(.easeIn(duration: 0.1), value: character.opacity)
        }
      }
      .onAppear {
        calculateGrid(geometry: geometry)
        startAnimation()
      }
    }
    .onDisappear {
      timer?.invalidate()
    }
    .ignoresSafeArea()
    .enableInjection()
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif

  private func calculateGrid(geometry: GeometryProxy) {
    let screenWidth = geometry.size.width
    let screenHeight = geometry.size.height

    maxColumns = Int(screenWidth / characterWidth)
    maxRows = Int(screenHeight / lineHeight)
  }

  private func addRandomCharacter() {
    guard maxColumns > 0 && maxRows > 0 else { return }

    for _ in 0..<charactersPerSpawn {
      let randomChar = possibleCharacters.randomElement() ?? "A"

      // Calculate position based on current row and column
      let x = Double(currentColumn) * Double(characterWidth) + Double(characterWidth / 2)
      let y = Double(currentRow) * Double(lineHeight) + Double(lineHeight)

      let newCharacter = RandomCharacter(
        char: randomChar,
        x: x,
        y: y,
        opacity: 1.0
      )

      characters.append(newCharacter)

      // Move to next position
      currentColumn += 1
      if currentColumn >= maxColumns {
        currentColumn = 0
        currentRow += 1
      }

      // Stop when screen is full
      if currentRow >= maxRows {
        timer?.invalidate()
        print("finished")
        return
      }
    }
  }

  private func startAnimation() {
    timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
      addRandomCharacter()
      updateSpeed()
    }
  }

  private func updateSpeed() {
    // Gradually decrease time interval (speed up)
    if timeInterval > 0.002 {
      timeInterval *= 0.95
    }

    // Gradually increase characters per spawn
    if characters.count > 50 && charactersPerSpawn < 3 {
      charactersPerSpawn = 2
    } else if characters.count > 150 && charactersPerSpawn < 5 {
      charactersPerSpawn = 3
    } else if characters.count > 300 && charactersPerSpawn < 8 {
      charactersPerSpawn = 5
    }

    // Restart timer with new interval
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
      addRandomCharacter()
      updateSpeed()
    }
  }
}

struct RandomCharacter: Identifiable {
  let id = UUID()
  let char: Character
  let x: Double
  let y: Double
  let opacity: Double
}

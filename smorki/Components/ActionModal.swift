import SwiftUI

struct ActionModal: View {
  @Binding var userInput: String
  @Binding var dynamicH: Double
  @Binding var showModal: Bool
  let submitMessageSync: (_ val: String?) -> Void
  @State var disabled: Bool = false
  var options: [ActionOption]

  var body: some View {
    VStack {
      VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.green, lineWidth: 2)
          .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {

              Text("Your next action here")
                .padding(.horizontal, 2)
                .background(.black)
                .foregroundColor(.green)
                .zIndex(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .offset(y: -8)

              TextEditor(text: $userInput)
                .frame(minHeight: dynamicH, maxHeight: dynamicH)
                .foregroundColor(.green)
                .tint(.green)
                .onChange(of: userInput) { result in
                  if userInput == "> " || userInput == ">" || userInput.isEmpty {
                    disabled = true
                  } else {
                    disabled = false
                  }

                  withAnimation(.interpolatingSpring) {
                    dynamicH = result.count <= 75 ? 35 : 100
                  }
                }
                .onSubmit {
                  submitMessageSync(nil)
                }
            }
            .padding(.horizontal, 8)
          }
          .padding(.horizontal)
      }
      .frame(minHeight: dynamicH + 32, maxHeight: dynamicH + 32)

      HStack(spacing: 10) {

        Button(action: {
          self.showModal = false
        }) {
          Text("◄ go back")
            .frame(maxWidth: 80)
            .padding()
            .foregroundColor(.green)
            .background {
              RoundedRectangle(cornerRadius: 8)
                .stroke(.green, lineWidth: 2)
            }
        }

        Button(action: { submitMessageSync(nil) }) {
          Text("► send")
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.green)
            .background {
              RoundedRectangle(cornerRadius: 8)
                .stroke(.green, lineWidth: 2)
            }
        }
        .disabled(disabled)
      }
      .padding(.horizontal)

      if self.options.count > 0 {
        Text("or")
          .foregroundStyle(.green)
          .font(.departure(size: 12))
      }

      ForEach(options) { option in
        Button(action: { submitMessageSync(option.text) }) {
          Text("> " + option.text)
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.green)
            .font(.departure(size: 12))
            .background {
              RoundedRectangle(cornerRadius: 8)
                .stroke(.green, lineWidth: 2)
                .overlay(alignment: .topLeading) {
                  Text("> " + option.id)
                    .font(.departure(size: 10))
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                    .background(.black)
                    .zIndex(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .offset(y: -8)
                }
            }
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 4)
    }
    .enableInjection()
  }

  #if DEBUG
    @ObserveInjection var forceRedraw
  #endif

}

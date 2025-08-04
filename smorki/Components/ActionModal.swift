import SwiftUI

struct ActionModal: View {
 @Binding var userInput: String 
  @Binding var dynamicH: Double
  @Binding var showModal: Bool
  let submitMessageSync: () -> Void

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
                // .font(.caption)
                .foregroundColor(.green)
                .zIndex(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .offset(y: -8)

              TextEditor(text: $userInput)
                .frame(minHeight: dynamicH, maxHeight: dynamicH)  // Use minHeight/maxHeight to hug
                // .padding(8)
                .foregroundColor(.green)
                .tint(.green)
                .onChange(of: userInput) { result in
                  withAnimation(.interpolatingSpring) {
                    dynamicH = result.count <= 75 ? 35 : 100
                  }
                }
                .onSubmit {
                  submitMessageSync()
                }
            }
            .padding(.horizontal, 8)
          }
          .padding(.horizontal)
      }
      .frame(minHeight: dynamicH + 32, maxHeight: dynamicH + 32)  // Use minHeight/maxHeight to hug

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

        Button(action: submitMessageSync) {
          Text("► send")
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.green)
            .background {
              RoundedRectangle(cornerRadius: 8)
                .stroke(.green, lineWidth: 2)
            }
        }
      }
      .padding(.horizontal)

    }

      .enableInjection()
  }

  #if DEBUG
  @ObserveInjection var forceRedraw
  #endif

}

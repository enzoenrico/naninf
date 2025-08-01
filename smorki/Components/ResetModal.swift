import SwiftUI

struct ResetAdventureModal: View {
    @Binding var isPresented: Bool
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Reset Adventure")
                .font(.departure(size: 20))
                .foregroundColor(.green)
                .padding(.top)
            
            Text("Are you sure you want to reset your adventure? This will clear all progress and start fresh.")
                .font(.departure(size: 14))
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.green)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                
                Button("Reset") {
                    onReset()
                    isPresented = false
                }
                .foregroundColor(.red)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 1)
                )
            }
            .padding(.bottom)
        }
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 2)
        )
        .padding()
    }
}
//
//  ContentView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct ContentView: View {
	@State var userInput: String = ""
	@State var isLarger: Bool = false
	@State var showContextualButton: Bool = false

	@State var vm = ContentViewModel()

	var body: some View {
		VStack {
			GameHeader()
				.frame(height: 50)
				.zIndex(2)

			VStack {
				VStack {
					Image(.bread)  // change to rendered
						.resizable()
						.interpolation(.none)
						.interpolation(.none)
						.scaledToFill()
						.padding()
						.frame(height: isLarger ? 10 : .infinity)
						.foregroundStyle(.accent)
				}
				.clipped()
				.drawBorder()

				ActionStack {
					TypeWriterView(
						"Sint anim pariatur est qui adipisicing commodo ex nisi consequat reprehenderit. Id cupidatat voluptate fugiat consequat officia non voluptate do commodo mollit ullamco nostrud cillum. Nulla esse laboris culpa Lorem ut fugiat anim occaecat nisi magna. Ullamco sint non occaecat cupidatat pariatur eu velit aliqua excepteur. Commodo aliquip elit nostrud et et enim sint exercitation dolore. Amet magna Lorem nisi tempor. Do dolore occaecat occaecat velit adipisicing. Duis amet qui ut velit elit. Consectetur magna laboris nostrud in veniam ut occaecat aliqua velit velit cupidatat cupidatat nulla eiusmod eiusmod. Excepteur duis in dolor in."
					)
					.padding()
				}
				.offset(y: isLarger ? 0 : -20)
				.frame(width: .infinity)
				.onTapGesture {
					withAnimation(.easeInOut) {
						isLarger.toggle()
					}
				}
				.padding(.horizontal, isLarger ? 0 : 8)
				.padding(.vertical, isLarger ? 8 : 0)

				// Spacer()

				if !showContextualButton {
					ContextualButton(type: .write) {
						//vm.getImage()
                        vm.getResponse() 
					}
					.padding(.bottom, 8)
				}
			}
			// .drawBorder("Game")
		}
		// .ignoresSafeArea()
		.background(Color.background)
		.padding()
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

#Preview {
	ContentView()
}

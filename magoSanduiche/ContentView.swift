//
//  ContentView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct ContentView: View {
	@State var userInput: String = ""
	@State var isClosed: Bool = false
	@State var showContextualButton: Bool = false

	var body: some View {
		VStack {
			GameHeader()
				.frame(height: 50)

			VStack {
                VStack{
                    Image(.bread)  // change to rendered
                        .interpolation(.none)
                        .resizable()
                        .scaledToFill()
                        .padding()
                }
                .clipped()

				ActionStack {
					TypeWriterView(
						"Sint anim pariatur est qui adipisicing commodo ex nisi consequat reprehenderit. Id cupidatat voluptate fugiat consequat officia non voluptate do commodo mollit ullamco nostrud cillum. Nulla esse laboris culpa Lorem ut fugiat anim occaecat nisi magna. Ullamco sint non occaecat cupidatat pariatur eu velit aliqua excepteur. Commodo aliquip elit nostrud et et enim sint exercitation dolore. Amet magna Lorem nisi tempor. Do dolore occaecat occaecat velit adipisicing. Duis amet qui ut velit elit. Consectetur magna laboris nostrud in veniam ut occaecat aliqua velit velit cupidatat cupidatat nulla eiusmod eiusmod. Excepteur duis in dolor in."
					)
					.padding()
				}
				.offset(y: -20)
				.frame(width: .infinity)
				.frame(height: isClosed ? 50 : .infinity)
				.onTapGesture {
					withAnimation(.easeInOut) {
						isClosed.toggle()
					}
				}
				.border(.red, width: 1)

				Spacer()

				if !showContextualButton {
					ContextualButton(action: .write)
						.padding(.bottom, 8)
				}
			}
			.padding(.horizontal, 8)
			.drawBorder("Game")
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

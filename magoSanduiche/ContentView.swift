//
//  ContentView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI

struct ContentView: View {
	@State var userInput: String = ""
	var body: some View {
		VStack {

			// MARK: - header
			HStack {
				VStack {
					Image(systemName: "house.fill")
						.resizable()
						.scaledToFit()
						.foregroundStyle(.accent)
						.padding()
				}
				.frame(width: 100)
				.drawBorder()

				VStack(alignment: .leading) {
					AsciiProgressBar(.health, progress: 10)  // add viewmodel values
					AsciiProgressBar(.mana, progress: 10)  // add viewmodel values
				}
				.frame(height: 100)
			}
			.frame(height: 100)

			VStack {
				Image(systemName: "house.fill")  // change to rendered
					.resizable()
					.scaledToFit()
					.drawBorder("Game")

				ActionStack {
					TypeWriterView(
						"Sint anim pariatur est qui adipisicing commodo ex nisi consequat reprehenderit. Id cupidatat voluptate fugiat consequat officia non voluptate do commodo mollit ullamco nostrud cillum. Nulla esse laboris culpa Lorem ut fugiat anim occaecat nisi magna. Ullamco sint non occaecat cupidatat pariatur eu velit aliqua excepteur. Commodo aliquip elit nostrud et et enim sint exercitation dolore. Amet magna Lorem nisi tempor. Do dolore occaecat occaecat velit adipisicing. Duis amet qui ut velit elit. Consectetur magna laboris nostrud in veniam ut occaecat aliqua velit velit cupidatat cupidatat nulla eiusmod eiusmod. Excepteur duis in dolor in."
					)
                    .frame(width: .infinity)
				}
			}
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

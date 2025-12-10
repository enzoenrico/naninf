//
//  ContentView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftUI
import TipKit

struct GameView: View {
	@State var userInput: String = ""
	@State var textFocus: Bool = true
	@State var showContextualButton: Bool = false

	@State private var actionAreaTip = ActionAreaTip()
	@State private var imageSectionTip = ImageSectionTip()
	@State private var actionButtonTip = ActionButtonTip()
	@State private var statBarsTip = StatBarsTip()
	@State private var tipsConfigured = false

	@State var vm = GameViewModel()

	var body: some View {
		let sceneImage = VStack {
			Image(.bread)  // change to rendered
				.resizable()
				.interpolation(.none)
				.interpolation(.none)
				.scaledToFill()
				.padding()
				.frame(height: textFocus ? 10 : .infinity)
				.foregroundStyle(.accent)
		}
		.clipped()
		.drawBorder()

		VStack {
			GameHeader()
				.popoverTip(statBarsTip, arrowEdge: .bottom)
				.frame(height: 50)
				.zIndex(2)

			VStack {
				if textFocus {
					sceneImage
				} else {
					sceneImage
						.popoverTip(imageSectionTip, arrowEdge: .top)
				}

				ActionStack {
					TypeWriterView(
						"Sint anim pariatur est qui adipisicing commodo ex nisi consequat reprehenderit. Id cupidatat voluptate fugiat consequat officia non voluptate do commodo mollit ullamco nostrud cillum. Nulla esse laboris culpa Lorem ut fugiat anim occaecat nisi magna. Ullamco sint non occaecat cupidatat pariatur eu velit aliqua excepteur. Commodo aliquip elit nostrud et et enim sint exercitation dolore. Amet magna Lorem nisi tempor. Do dolore occaecat occaecat velit adipisicing. Duis amet qui ut velit elit. Consectetur magna laboris nostrud in veniam ut occaecat aliqua velit velit cupidatat cupidatat nulla eiusmod eiusmod. Excepteur duis in dolor in."
					)
					.padding()
				}
				.popoverTip(actionAreaTip, arrowEdge: .top)
				.offset(y: textFocus ? 0 : -20)
				.frame(width: .infinity)
				.onTapGesture {
					withAnimation(.easeInOut) {
						textFocus.toggle()
					}
				}
				.padding(.horizontal, textFocus ? 0 : 8)
				.padding(.vertical, textFocus ? 8 : 0)

				// Spacer()

				if !showContextualButton {
					ContextualButton(type: .write) {
						//vm.getImage()
                        vm.getResponse() 
					}
					.popoverTip(actionButtonTip, arrowEdge: .top)
					.padding(.bottom, 8)
				}
			}
			// .drawBorder("Game")
		}
		// .ignoresSafeArea()
            .navigationBarBackButtonHidden()
            .ignoresSafeArea()
		.padding()
		.background(Color.background)
		.tipViewStyle(AsciiTipStyle())
		.task {
			guard !tipsConfigured else { return }
			try? await Tips.configure([.displayFrequency(.immediate)])
			tipsConfigured = true
		}
		.enableInjection()
	}

	#if DEBUG
		@ObserveInjection var forceRedraw
	#endif
}

#Preview {
	GameView()
}

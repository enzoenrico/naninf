//
//  InputBox.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 10/12/25.
//

import SwiftUI

struct InputBox: View {
	var textbinding: Binding<String>

	init(with bind: Binding<String>) {
		self.textbinding = bind
	}

	var body: some View {

		TextField("Describe your next action", text: textbinding)
			.disableAutocorrection(true)
			.padding(8)
			.drawBorder()
	}
}

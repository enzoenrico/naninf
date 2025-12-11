//
//  InputBox.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 10/12/25.
//

import SwiftUI

struct InputBox: View {
	var textbinding: Binding<String>
	var isDisabled: Bool

	init(with bind: Binding<String>, isDisabled: Bool = false) {
		self.textbinding = bind
		self.isDisabled = isDisabled
	}

	var body: some View {

		TextField("Describe your next action", text: textbinding)
			.disableAutocorrection(true)
			.disabled(isDisabled)
			.padding(8)
			.drawBorder()
	}
}

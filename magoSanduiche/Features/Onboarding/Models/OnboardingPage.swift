//
//  OnboardingPage.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct OnboardingPage: Identifiable {
	let id = UUID()
	let title: String
	let message: String
	let image: ImageResource
	let command: String
}

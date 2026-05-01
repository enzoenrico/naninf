//
//  RootView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct RootView: View {
	@State private var coordinator = AppCoordinator()

	var body: some View {
		AppCoordinatorView()
			.environment(coordinator)
	}
}

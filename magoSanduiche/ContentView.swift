//
//  ContentView.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 09/12/25.
//

import SwiftUI

struct ContentView: View {
    private var coordinator = AppCoordinator()
	var body: some View {
		AppCoordinatorView()
            .environment(coordinator)
	}
}

//
//  magoSanduicheApp.swift
//  magoSanduiche
//
//  Created by Enzo Enrico on 01/12/25.
//

import SwiftData
import SwiftUI

@main
struct magoSanduicheApp: App {
	@State private var authSessionStore: AuthSessionStore
	private let modelContainer: ModelContainer

	init() {
		AppAnalytics.configure()

		#if DEBUG
			UITestConfiguration.applyLaunchSeedIfNeeded()
			if let container = UITestConfiguration.makeModelContainerIfNeeded() {
				modelContainer = container
				_authSessionStore = State(initialValue: AuthSessionStore(uiTestMode: UITestConfiguration.authMode))
			} else {
				modelContainer = Self.makeDefaultContainer()
				_authSessionStore = State(initialValue: AuthSessionStore())
			}
		#else
			modelContainer = Self.makeDefaultContainer()
			_authSessionStore = State(initialValue: AuthSessionStore())
		#endif
	}

	private static func makeDefaultContainer() -> ModelContainer {
		do {
			return try ModelContainer(for: StoredGameRun.self)
		} catch {
			fatalError("Failed to create ModelContainer: \(error)")
		}
	}

	var body: some Scene {
		WindowGroup {
			AppStartupGate()
				.background(Color.background)
				.font(.monocraft())
				.environment(authSessionStore)
				.modelContainer(modelContainer)
				.task {
					await authSessionStore.start()
				}
				.onOpenURL { url in
					authSessionStore.handleOpenURL(url)
				}
		}
	}
}

#if canImport(HotSwiftUI)
	@_exported import HotSwiftUI
#elseif canImport(Inject)
	@_exported import Inject
#else
	// This code can be found in the Swift package:
	// https://github.com/johnno1962/HotSwiftUI

	#if DEBUG
		import Combine

		private var loadInjectionOnce: () = {
			guard objc_getClass("InjectionClient") == nil else {
				return
			}
			#if os(macOS) || targetEnvironment(macCatalyst)
				let bundleName = "macOSInjection.bundle"
			#elseif os(tvOS)
				let bundleName = "tvOSInjection.bundle"
			#elseif os(visionOS)
				let bundleName = "xrOSInjection.bundle"
			#elseif targetEnvironment(simulator)
				let bundleName = "iOSInjection.bundle"
			#else
				let bundleName = "maciOSInjection.bundle"
			#endif
			let bundlePath = "/Applications/InjectionIII.app/Contents/Resources/" + bundleName
			guard let bundle = Bundle(path: bundlePath), bundle.load() else {
				return
			}
		}()

		public let injectionObserver = InjectionObserver()

		public class InjectionObserver: ObservableObject {
			@Published var injectionNumber = 0
			var cancellable: AnyCancellable?
			let publisher = PassthroughSubject<Void, Never>()
			init() {
				_ = loadInjectionOnce  // .enableInjection() optional Xcode 16+
				cancellable = NotificationCenter.default.publisher(
					for:
						Notification.Name("INJECTION_BUNDLE_NOTIFICATION")
				)
				.sink { [weak self] _ in
					self?.injectionNumber += 1
					self?.publisher.send()
				}
			}
		}

		extension SwiftUI.View {
			public func eraseToAnyView() -> some SwiftUI.View {
				_ = loadInjectionOnce
				return AnyView(self)
			}
			public func enableInjection() -> some SwiftUI.View {
				return eraseToAnyView()
			}
			public func loadInjection() -> some SwiftUI.View {
				return eraseToAnyView()
			}
			public func onInjection(bumpState: @escaping () -> Void) -> some SwiftUI.View {
				return
					self
					.onReceive(injectionObserver.publisher, perform: bumpState)
					.eraseToAnyView()
			}
		}

		@available(iOS 13.0, *)
		@propertyWrapper
		public struct ObserveInjection: DynamicProperty {
			@ObservedObject private var iO = injectionObserver
			public init() {}
			public private(set) var wrappedValue: Int {
				get { 0 }
				set {}
			}
		}
	#else
		extension SwiftUI.View {
			@inline(__always)
			public func eraseToAnyView() -> some SwiftUI.View { return self }
			@inline(__always)
			public func enableInjection() -> some SwiftUI.View { return self }
			@inline(__always)
			public func loadInjection() -> some SwiftUI.View { return self }
			@inline(__always)
			public func onInjection(bumpState: @escaping () -> Void) -> some SwiftUI.View {
				return self
			}
		}

		@available(iOS 13.0, *)
		@propertyWrapper
		public struct ObserveInjection {
			public init() {}
			public private(set) var wrappedValue: Int {
				get { 0 }
				set {}
			}
		}
	#endif
#endif

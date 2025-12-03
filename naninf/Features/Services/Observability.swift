import FirebaseAnalytics
import Foundation

public final class Observability: ObservableObject {
  public static let shared = Observability()
  init() {}

  // MARK: - Core API

  public func logEvent(_ name: String, parameters: [String: Any]? = nil) {
    #if DEBUG
      print("[Analytics] \(name) params=\(parameters ?? [:])")
    #endif
    Analytics.logEvent(name, parameters: parameters)
  }

  public func setUserID(_ id: String?) {
    Analytics.setUserID(id)
  }

  public func setUserProperty(_ value: String?, forName name: String) {
    Analytics.setUserProperty(value, forName: name)
  }

  public func logScreenView(screenName: String, screenClass: String? = nil) {
    Analytics.logEvent(
      AnalyticsEventScreenView,
      parameters: [
        AnalyticsParameterScreenName: screenName,
        AnalyticsParameterScreenClass: screenClass ?? "UIViewController",
      ])
  }

  // MARK: - Static conveniences

  public static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
    shared.logEvent(name, parameters: parameters)
  }

  public static func setUserID(_ id: String?) {
    shared.setUserID(id)
  }

  public static func setUserProperty(_ value: String?, forName name: String) {
    shared.setUserProperty(value, forName: name)
  }

  public static func logScreenView(screenName: String, screenClass: String? = nil) {
    shared.logScreenView(screenName: screenName, screenClass: screenClass)
  }

}

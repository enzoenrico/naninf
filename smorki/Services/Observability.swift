import FirebaseAnalytics
import Foundation

public final class Observability: ObservableObject {
  init() {}

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
    logEvent(
      AnalyticsEventScreenView,
      parameters: [
        AnalyticsParameterScreenName: screenName,
        AnalyticsParameterScreenClass: screenClass ?? "UIViewController",
      ])
  }

  public func logNewMessage(messageCount: Int) {
    logEvent("new_message", parameters: [
      "message_count": messageCount
    ])
  }

  public func logSessionEnded(messageCount: Int) {
    logEvent("session_ended", parameters: [
      "message_count": messageCount
    ])
  }

}

import SwiftUI

@main
struct OpenDivingApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    WindowGroup {
      RootView(
        session: delegate.session, account: delegate.account, inbox: delegate.inbox,
        engine: delegate.engine, notices: delegate.notices)
    }
  }
}

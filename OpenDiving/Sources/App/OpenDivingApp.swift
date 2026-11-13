import SwiftUI

@main
struct OpenDivingApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    WindowGroup {
      RootView(watch: delegate.watch)
    }
  }
}

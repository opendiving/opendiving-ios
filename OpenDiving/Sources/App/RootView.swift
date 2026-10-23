import OpenDivingKit
import SwiftUI

/// What the window shows, and where the one session is injected. A placeholder until the
/// signed-out and signing-in states exist; for now it is always the signed-in shell.
struct RootView: View {
  @State private var session = Session.device()

  var body: some View {
    MainTabView()
      .environment(session)
  }
}

#Preview {
  RootView()
}

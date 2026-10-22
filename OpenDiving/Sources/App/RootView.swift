import SwiftUI

/// What the window shows. A placeholder until the signed-out and signing-in states exist;
/// for now it is always the signed-in shell.
struct RootView: View {
  var body: some View {
    MainTabView()
  }
}

#Preview {
  RootView()
}

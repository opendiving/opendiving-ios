import OpenDivingKit
import SwiftUI

extension View {
  /// A control only the server can carry out, disabled while the phone has no route to it.
  func needsServer() -> some View {
    modifier(NeedsServer())
  }
}

private struct NeedsServer: ViewModifier {
  @Environment(Session.self) private var session

  func body(content: Content) -> some View {
    content.disabled(!session.hasRoute)
  }
}

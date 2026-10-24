import OpenDivingKit
import SwiftUI

extension View {
  /// Where the writes waiting to sync are sent from, for the window's whole life: the outbox
  /// model in the environment, and a flush with a refresh of the pickers' lookups on the
  /// connectivity seam's moments and whenever the session changes — signed in, signed out, the
  /// account loaded. While no account load has returned in this process a moment runs the
  /// model's load first, the one it was built with, and flushes on its success.
  func outboxHost(_ outbox: OutboxModel, session: Session) -> some View {
    modifier(OutboxHost(outbox: outbox, session: session))
  }
}

private struct OutboxHost: ViewModifier {
  let outbox: OutboxModel
  let session: Session

  func body(content: Content) -> some View {
    content
      .environment(outbox)
      .task { await outbox.watch() }
      .onChange(of: session.state) { outbox.sessionChanged() }
      .onChange(of: session.accountLoaded) { outbox.sessionChanged() }
  }
}

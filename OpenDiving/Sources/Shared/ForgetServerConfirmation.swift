import OpenDivingKit
import SwiftUI

/// The one confirmation *Forget this server* asks for, wherever it is offered: the server
/// screen, the signed-out screen and Settings.
struct ForgetServerConfirmation: ViewModifier {
  @Environment(Session.self) private var session
  @Binding var origin: ServerOrigin?
  let perform: (ServerOrigin) -> Void

  /// Under a *Forget* offered for a server that is not active.
  static func heldMessage(_ origin: ServerOrigin) -> String {
    KeptText.held(origin)
  }

  func body(content: Content) -> some View {
    content.confirmationDialog(
      title, isPresented: Binding(get: { origin != nil }, set: { if !$0 { origin = nil } }),
      titleVisibility: .visible, presenting: origin
    ) { origin in
      Button("Forget", role: .destructive) { perform(origin) }
    } message: { origin in
      // Read when it is asked: every account's writes on the server, which `forget` discards.
      Text(KeptText.forgetMessage(OutboxStore.summary(store: session.store, origin: origin)))
    }
  }

  private var title: String {
    origin.map { "Forget \($0)?" } ?? "Forget this server?"
  }
}

extension View {
  /// Asks before forgetting `origin`, while it is set.
  func forgetServerConfirmation(
    origin: Binding<ServerOrigin?>, perform: @escaping (ServerOrigin) -> Void
  ) -> some View {
    modifier(ForgetServerConfirmation(origin: origin, perform: perform))
  }
}

#Preview {
  @Previewable @State var origin: ServerOrigin? = ServerOrigin("https://opendiving.app")
  Button("Forget this server", role: .destructive) {
    origin = ServerOrigin("https://opendiving.app")
  }
  .forgetServerConfirmation(origin: $origin) { _ in }
  .environment(Session.signedOutStub(transport: StubTransport(routes: [:])))
}

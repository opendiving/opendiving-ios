import OpenDivingKit
import SwiftUI

/// The one confirmation *Forget this server* asks for, wherever it is offered: the server
/// screen, the signed-out screen and Settings.
struct ForgetServerConfirmation: ViewModifier {
  @Binding var origin: ServerOrigin?
  let perform: (ServerOrigin) -> Void

  /// Under a *Forget* offered for a server that is not active.
  static func heldMessage(_ origin: ServerOrigin) -> String {
    "This phone holds a sign-in, an account or a check-in sheet for \(origin)."
  }

  func body(content: Content) -> some View {
    content.confirmationDialog(
      title, isPresented: Binding(get: { origin != nil }, set: { if !$0 { origin = nil } }),
      titleVisibility: .visible, presenting: origin
    ) { origin in
      Button("Forget", role: .destructive) { perform(origin) }
    } message: { _ in
      Text(
        "Removes the server's sign-in, your account details and the saved check-in sheet from"
          + " this phone. It signs out on the server first when it can; it removes them even"
          + " when the server cannot be reached.")
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
}

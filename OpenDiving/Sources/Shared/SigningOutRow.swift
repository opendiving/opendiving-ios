import OpenDivingKit
import SwiftUI

/// The server a sign-out is waiting on, and the way out of the wait: in Settings, on the servers
/// and add-server screens and on a saved server's page, wherever the sign-out started.
struct SigningOutRow: View {
  let origin: ServerOrigin
  let stop: () -> Void

  var body: some View {
    HStack {
      ProgressView()
      Text("Signing out of \(origin.description)…")
    }
    .foregroundStyle(.secondary)
    Button("Stop waiting", action: stop)
      .accentRow()
  }
}

#Preview {
  List {
    SigningOutRow(origin: ServerOrigin("https://opendiving.app")!) {}
  }
}

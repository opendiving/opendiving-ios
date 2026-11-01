import OpenDivingKit
import SwiftUI

/// The server card — its address, the build it runs and an unencrypted connection's warning —
/// with what the screen offers for the server beneath: Settings, a saved server's page and the
/// sign-in screen draw the same one.
struct ServerCard<Actions: View>: View {
  let content: ServerCardContent
  @ViewBuilder let actions: Actions

  var body: some View {
    Section("Server") {
      LabeledContent("Address", value: content.address)
      LabeledContent("Version", value: content.version)
      if !content.isEncrypted {
        Label("The connection to this server is not encrypted.", systemImage: "lock.open")
          .foregroundStyle(.orange)
      }
      actions
    }
  }
}

extension ServerCard where Actions == EmptyView {
  init(content: ServerCardContent) {
    self.init(content: content) { EmptyView() }
  }
}

#Preview {
  Form {
    ServerCard(
      content: ServerCardContent(origin: ServerOrigin("http://192.168.1.20:8000")!, health: nil)
    ) {
      Button("Change server") {}
    }
  }
}

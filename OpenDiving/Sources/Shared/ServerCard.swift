import OpenDivingKit
import SwiftUI

/// The server card — its address, the build it runs and an unencrypted connection's warning —
/// with what the screen offers for the server beneath: Settings, a saved server's page and the
/// sign-in screen draw the same one.
struct ServerCard<Actions: View>: View {
  let content: ServerCardContent
  @ViewBuilder let actions: Actions
  @State private var showsFailure = false

  var body: some View {
    Section("Server") {
      LabeledContent("Address", value: content.address)
      LabeledContent("Version") {
        HStack {
          if content.isUpdating {
            ProgressView()
          } else if let failure = content.updateFailure {
            Button {
              showsFailure = true
            } label: {
              Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Why the version could not be updated")
            .alert("The version could not be updated", isPresented: $showsFailure) {
              Button("OK", role: .cancel) {}
            } message: {
              Text(failure)
            }
          }
          Text(content.version)
        }
      }
      if !content.isEncrypted {
        Label("Connection is not encrypted.", systemImage: "lock.open")
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
      content: ServerCardContent(
        origin: ServerOrigin("http://192.168.1.20:8000")!, health: nil,
        updateFailure: "The server could not be reached.")
    ) {
      Button("Change server") {}
    }
  }
}

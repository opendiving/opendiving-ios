import OpenDivingKit
import SwiftUI

/// *Settings* → *Authentication*: the passkeys, the signed-in devices and the API keys, each
/// block left out where the server has no such list.
struct AuthenticationScreen: View {
  @Environment(Session.self) private var session

  var body: some View {
    AuthenticationList(session: session)
      .navigationTitle(SettingsSection.authentication.title)
      .followsAccount(session)
  }
}

private struct AuthenticationList: View {
  @State private var passkeys: PasskeysModel
  @State private var devices: SignedInDevicesModel
  @State private var apiKeys: APIKeysModel

  init(session: Session) {
    _passkeys = State(initialValue: PasskeysModel(session: session))
    _devices = State(initialValue: SignedInDevicesModel(session: session))
    _apiKeys = State(initialValue: APIKeysModel(session: session))
  }

  var body: some View {
    List {
      PasskeysSection(model: passkeys)
      SignedInDevicesSection(model: devices)
      APIKeysSection(model: apiKeys)
    }
    .task { await load() }
    .task { await passkeys.list.followRoute() }
    .task { await devices.list.followRoute() }
    .task { await apiKeys.list.followRoute() }
    .refreshable { await load() }
    // Leaving the screen lets a new key's secret go: it is never shown again.
    .onDisappear { apiKeys.done() }
  }

  private func load() async {
    async let passkeysRead: Void = passkeys.list.load()
    async let devicesRead: Void = devices.list.load()
    async let keysRead: Void = apiKeys.list.load()
    _ = await (passkeysRead, devicesRead, keysRead)
  }
}

/// A block's list while it is not there to show: loading, or why it could not be read.
struct OptionalListStatus<Value: Sendable>: View {
  let list: OptionalList<Value>
  /// The web's sentence for a list that could not be read.
  let failed: String
  let loading: String

  var body: some View {
    if let failure = list.failure, list.value == nil {
      VStack(alignment: .leading, spacing: 8) {
        Text(failed + " " + failure)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .buttonStyle(.borderless)
      }
    } else if list.value == nil {
      HStack {
        BubbleSpinner()
        Text(loading)
      }
      .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  NavigationStack {
    AuthenticationScreen()
  }
  .environment(AuthenticationPreviewData.session)
}

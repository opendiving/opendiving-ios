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
  @State private var openedKey: APIKeyRead?

  init(session: Session) {
    _passkeys = State(initialValue: PasskeysModel(session: session))
    _devices = State(initialValue: SignedInDevicesModel(session: session))
    _apiKeys = State(initialValue: APIKeysModel(session: session))
  }

  var body: some View {
    List {
      PasskeysSection(model: passkeys)
      SignedInDevicesSection(model: devices)
      APIKeysSection(model: apiKeys, opened: $openedKey)
    }
    .task { await load() }
    .task { await passkeys.list.followRoute() }
    .task { await devices.list.followRoute() }
    // A key's last use happens elsewhere, so its row is read again as the app comes back.
    .task { await apiKeys.list.followRouteAndForeground() }
    .bubbleRefreshable { await load() }
    .navigationDestination(item: $openedKey) { key in
      APIKeyScreen(model: apiKeys, key: key)
    }
    // Leaving the screen lets a new key's secret go: it is never shown again. A key's own page
    // covers the screen without leaving it.
    .onDisappear {
      if openedKey == nil { apiKeys.done() }
    }
  }

  private func load() async {
    async let passkeysRead: Void = passkeys.list.load()
    async let devicesRead: Void = devices.list.load()
    async let keysRead: Void = apiKeys.list.load()
    _ = await (passkeysRead, devicesRead, keysRead)
  }
}

#Preview {
  NavigationStack {
    AuthenticationScreen()
  }
  .environment(AuthenticationPreviewData.session)
}

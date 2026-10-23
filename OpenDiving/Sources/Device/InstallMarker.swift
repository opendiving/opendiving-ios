import Foundation

/// Tells the first launch of an install from every later one, by a flag in the app's defaults:
/// deleting the app removes the defaults but not its Keychain items, so a launch that finds no
/// flag holds whatever tokens the install before it left behind.
nonisolated struct InstallMarker {
  static let key = "installKeychainCleared"

  var defaults = UserDefaults.standard

  /// Clears `secrets` on the first launch of an install. The flag is set only once the clear
  /// succeeded, so a failed one is tried again at the next launch.
  func clearOnFirstLaunch(_ secrets: KeychainSecretStore) throws {
    guard !defaults.bool(forKey: Self.key) else { return }
    try secrets.removeAllSecrets()
    defaults.set(true, forKey: Self.key)
  }
}

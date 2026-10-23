import Foundation
import Testing

@testable import OpenDiving

struct InstallMarkerTests {
  private let secrets = KeychainSecretStore(
    service: "app.opendiving.ios.tests-\(UUID().uuidString)")
  private let suite = "app.opendiving.ios.tests-\(UUID().uuidString)"
  private let first = "https://first.example"
  private let second = "https://second.example"

  private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer {
      defaults.removePersistentDomain(forName: suite)
      try? secrets.removeAllSecrets()
    }
    try body(defaults)
  }

  @Test func theFirstLaunchClearsEveryServerAndSetsTheFlag() throws {
    try withDefaults { defaults in
      try secrets.setSecret("one", for: first)
      try secrets.setSecret("two", for: second)
      try InstallMarker(defaults: defaults).clearOnFirstLaunch(secrets)
      #expect(try secrets.secret(for: first) == nil)
      #expect(try secrets.secret(for: second) == nil)
      #expect(defaults.bool(forKey: InstallMarker.key))
    }
  }

  @Test func aLaterLaunchLeavesTheKeychainAlone() throws {
    try withDefaults { defaults in
      defaults.set(true, forKey: InstallMarker.key)
      try secrets.setSecret("one", for: first)
      try InstallMarker(defaults: defaults).clearOnFirstLaunch(secrets)
      #expect(try secrets.secret(for: first) == "one")
    }
  }

  @Test func theClearReachesNoOtherService() throws {
    let other = KeychainSecretStore(service: "app.opendiving.ios.tests-\(UUID().uuidString)")
    defer { try? other.removeAllSecrets() }
    try withDefaults { defaults in
      try other.setSecret("kept", for: first)
      try InstallMarker(defaults: defaults).clearOnFirstLaunch(secrets)
      #expect(try other.secret(for: first) == "kept")
    }
  }
}

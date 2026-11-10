import Foundation
import OpenDivingKit
import Testing

/// The appearance is the phone's: kept in the defaults, and the phone's own until chosen.
@MainActor
struct AppearanceModelTests {
  private let suite = "AppearanceModelTests-\(UUID().uuidString)"

  @Test func aFreshInstallFollowsThePhone() throws {
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(AppearanceModel(defaults: defaults).choice == .system)
  }

  @Test func theChoiceOutlivesTheModel() throws {
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    AppearanceModel(defaults: defaults).choice = .dark
    #expect(AppearanceModel(defaults: defaults).choice == .dark)
  }

  @Test func theChoiceIsKeptBesideNothingAServerOwns() async throws {
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    AppearanceModel(defaults: defaults).choice = .light
    let origin = ClientHarness.origin
    let session = Session(
      transport: StubTransport(routes: [:]), secrets: InMemorySecretStore(),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("AppearanceModelTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: ClientHarness.userAgent)
    try session.forget(origin)
    #expect(AppearanceModel(defaults: defaults).choice == .light)
  }
}

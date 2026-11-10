import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The account's writes from *Notifications* and *Preferences*: what is sent, what the session
/// holds afterwards and what a relaunch reads.
@MainActor
struct AccountWriteTests {
  private let origin = ClientHarness.origin
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("AccountWriteTests-\(UUID().uuidString)", isDirectory: true)

  private func session(
    _ server: SettingsServer, connectivity: SettingsConnectivity = SettingsConnectivity()
  ) -> Session {
    Session(
      transport: server, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity, applicationSupport: root, userAgent: ClientHarness.userAgent)
  }

  private func loaded(_ server: SettingsServer) async throws -> Session {
    let session = session(server)
    try await session.loadAccount()
    return session
  }

  private func writes(_ server: SettingsServer) -> [URLRequest] {
    server.requests.filter { $0.httpMethod == "PATCH" }
  }

  @Test func aSwitchSendsItsOwnKeyAloneAndTheSessionHoldsWhatTheServerAnswers() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = NotificationsModel(session: session)
    let sentBefore = server.requests.count

    await model.set(.yearInReview, false)

    let sent = server.requests.dropFirst(sentBefore).map(\.route)
    #expect(sent == ["PATCH user", "GET user"])
    #expect(
      writes(server).first?.json
        == (try JSONValue.parse(Data(#"{"year_in_review_emails":false}"#.utf8))))
    #expect(session.user == (try server.user()))
    #expect(!model.isOn(.yearInReview))
    #expect(model.isOn(.gearService))
    #expect(model.write.failure == nil)
  }

  @Test func aSwitchSetAsItStandsSendsNothing() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    await NotificationsModel(session: session).set(.gearService, true)
    #expect(writes(server).isEmpty)
  }

  @Test func theUnitsAreReadByARelaunchOfflineAndByTheSignedOutForm() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = PreferencesModel(session: session)

    await model.setUnits(.imperial)

    #expect(
      writes(server).first?.json == (try JSONValue.parse(Data(#"{"units":"imperial"}"#.utf8))))
    #expect(session.units == .imperial)
    #expect(model.units == .imperial)
    let offline = SettingsConnectivity(available: false)
    let relaunched = self.session(try SettingsServer(), connectivity: offline)
    #expect(relaunched.units == .imperial)
    let account = try #require(relaunched.store.lastAccount(for: origin))
    #expect(relaunched.store.formSettings(for: origin, account: account)?.units == .imperial)
  }

  @Test func aRefusedWriteReturnsToTheStoredValueAndSaysWhy() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PATCH user", with: .json(#"{"detail":"Something broke"}"#, status: 500))
    let model = NotificationsModel(session: session)

    await model.set(.renewalReminder, false)

    #expect(model.write.failure == "Something broke")
    #expect(model.isOn(.renewalReminder))
    #expect(session.user?.renewalReminderEmails == true)
  }

  @Test func withNoRouteNothingIsSentAndTheControlSaysSoAtOnce() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let session = session(server, connectivity: connectivity)
    try await session.loadAccount()
    connectivity.isRouteAvailable = false
    let model = PreferencesModel(session: session)

    await model.setUnits(.imperial)

    #expect(writes(server).isEmpty)
    #expect(model.write.failure == APIError.noRoute.message)
    #expect(model.units == .metric)
  }

  @Test func aWriteTakenWhoseReadFailsKeepsTheChoiceUntilTheNextRead() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("GET user", with: .json(#"{"detail":"Busy"}"#, status: 503))
    let model = PreferencesModel(session: session)

    await model.setUnits(.imperial)

    #expect(model.write.failure == nil)
    #expect(model.units == .imperial)
    // The rest of the app keeps what the session holds, which nothing patched.
    #expect(session.units == .metric)

    server.succeed("GET user")
    try await session.reloadAccount()
    #expect(session.units == .imperial)
    #expect(model.write.shown == nil)
  }

  @Test func aSecondSwitchDoesNotHideAFirstTheServerTookButThePhoneCouldNotReadBack()
    async throws
  {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let session = session(server, connectivity: connectivity)
    try await session.loadAccount()
    server.fail("GET user", with: .json(#"{"detail":"Busy"}"#, status: 503))
    let model = NotificationsModel(session: session)

    await model.set(.gearService, false)
    await model.set(.yearInReview, false)
    #expect(!model.isOn(.gearService))
    #expect(!model.isOn(.yearInReview))

    connectivity.isRouteAvailable = false
    await model.set(.renewalReminder, false)
    #expect(model.write.failure == APIError.noRoute.message)
    #expect(model.isOn(.renewalReminder))
    #expect(!model.isOn(.gearService))
    #expect(!model.isOn(.yearInReview))
    #expect(session.user?.gearServiceEmails == true)
  }

  @Test func whileOneSwitchSavesTheOthersWait() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let gate = Gate()
    server.hold("PATCH user", at: gate)
    let model = NotificationsModel(session: session)

    let first = Task { await model.set(.gearService, false) }
    await gate.untilArrived()
    #expect(model.write.isSaving)
    #expect(!model.isOn(.gearService))
    await model.set(.yearInReview, false)
    await gate.open()
    await first.value

    #expect(writes(server).count == 1)
    #expect(model.isOn(.yearInReview))
  }

  @Test func aReadThatLandsAfterTheSessionEndedStoresNothing() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let gate = Gate()
    server.hold("GET user", at: gate)

    let read = Task { try await session.reloadAccount() }
    await gate.untilArrived()
    try await session.signOut()
    await gate.open()
    try await read.value

    #expect(session.user == nil)
    #expect(session.store.rememberedUser(for: origin) == nil)
  }

  @Test func aSettingsScreenReadsTheAccountOnAppearingAndOnReturningToTheForeground() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let session = session(server, connectivity: connectivity)
    try await session.loadAccount()
    server.set("units", "imperial")

    let showing = Task { await session.followAccountWhileShowing() }
    while !connectivity.isFollowed { await Task.yield() }
    #expect(session.units == .imperial)

    server.set("year_in_review_emails", false)
    connectivity.becomeActive()
    while session.user?.yearInReviewEmails != false { await Task.yield() }
    showing.cancel()
    await showing.value
  }

  @Test func aSettingsScreenWithNoRouteReadsOnceOneAppears() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let session = session(server, connectivity: connectivity)
    try await session.loadAccount()
    connectivity.isRouteAvailable = false
    let sentBefore = server.requests.count
    server.set("units", "imperial")

    let showing = Task { await session.followAccountWhileShowing() }
    while !connectivity.isFollowed { await Task.yield() }
    #expect(server.requests.count == sentBefore)

    connectivity.appear()
    while session.units != .imperial { await Task.yield() }
    showing.cancel()
    await showing.value
  }
}

import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// *Account*'s name and username, and its email.
@MainActor
struct AccountFormTests {
  private let origin = ClientHarness.origin
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("AccountFormTests-\(UUID().uuidString)", isDirectory: true)

  private func loaded(
    _ server: SettingsServer, connectivity: SettingsConnectivity = SettingsConnectivity()
  ) async throws -> Session {
    let session = Session(
      transport: server, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity, applicationSupport: root, userAgent: ClientHarness.userAgent)
    try await session.loadAccount()
    return session
  }

  private func sent(_ server: SettingsServer, after count: Int) -> [String] {
    server.requests.dropFirst(count).map(\.route)
  }

  // MARK: - Name and username

  @Test func theFieldsShowTheAccountAndNothingIsSavedUntilOneChanges() async throws {
    let server = try SettingsServer()
    let model = AccountFormModel(session: try await loaded(server))
    #expect(model.name == "Test Diver")
    #expect(model.username == "testdiver")
    #expect(!model.canSave)
    model.setName("  Test Diver ")
    #expect(model.fieldsUpdate == nil)
    #expect(!model.canSave)
  }

  @Test func onlyWhatChangedIsSentTrimmedAndTheSessionHoldsTheAnswer() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = AccountFormModel(session: session)
    let before = server.requests.count

    model.setName(" Sam Diver ")
    #expect(model.canSave)
    await model.save()

    #expect(sent(server, after: before) == ["PATCH user", "GET user"])
    #expect(
      server.requests.first { $0.httpMethod == "PATCH" }?.json
        == (try JSONValue.parse(Data(#"{"name":"Sam Diver"}"#.utf8))))
    #expect(session.user?.name == "Sam Diver")
    #expect(model.name == "Sam Diver")
    #expect(model.saved)
    #expect(!model.canSave)
  }

  @Test func bothFieldsSaveTogether() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = AccountFormModel(session: session)
    model.setName("Sam Diver")
    model.setUsername("samdiver")
    await model.save()
    #expect(
      server.requests.first { $0.httpMethod == "PATCH" }?.json
        == (try JSONValue.parse(Data(#"{"name":"Sam Diver","username":"samdiver"}"#.utf8))))
    #expect(session.user?.username == "samdiver")
  }

  @Test func aTakenUsernameIsTheAPIsSentenceAndWhatWasTypedStays() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PATCH user", with: .json(#"{"detail":"Username not available"}"#, status: 422))
    let model = AccountFormModel(session: session)
    model.setUsername("taken")

    await model.save()

    #expect(model.failure == "Username not available")
    #expect(model.username == "taken")
    #expect(session.user?.username == "testdiver")
    #expect(!model.saved)
  }

  @Test func theWebsBoundsAreKeptBeforeAnythingIsSent() async throws {
    let server = try SettingsServer()
    let model = AccountFormModel(session: try await loaded(server))
    let before = server.requests.count

    model.setName("S")
    #expect(model.nameProblem == "Name must be at least 2 characters")
    model.setName(String(repeating: "a", count: 31))
    #expect(model.nameProblem == "Name cannot exceed 30 characters")
    model.setName(String(repeating: "a", count: 30))
    #expect(model.nameProblem == nil)
    model.setUsername("Sam")
    #expect(model.usernameProblem == "Username can only contain lowercase letters and numbers")
    model.setUsername(String(repeating: "a", count: 21))
    #expect(model.usernameProblem == "Username cannot exceed 20 characters")
    #expect(!model.canSave)
    await model.save()
    #expect(server.requests.count == before)
  }

  @Test func offlineNothingIsSentAndTheNoConnectionSentenceShowsAtOnce() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let session = try await loaded(server, connectivity: connectivity)
    connectivity.isRouteAvailable = false
    let model = AccountFormModel(session: session)
    let before = server.requests.count
    model.setName("Sam Diver")

    await model.save()

    #expect(server.requests.count == before)
    #expect(model.failure == APIError.noRoute.message)
    #expect(model.name == "Sam Diver")
  }

  // MARK: - Email

  @Test func aNewAddressIsSentTheLinkAndTheScreenSaysWhereItWent() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = EmailChangeModel(session: session)
    let before = server.requests.count

    model.setNewEmail(" new.diver@example.com ")
    await model.send()

    #expect(sent(server, after: before) == ["POST user/email-change/request"])
    #expect(
      server.requests.last?.json
        == (try JSONValue.parse(KitFixture.data("request-email-change"))))
    #expect(model.newEmail.isEmpty)
    #expect(model.failure == nil)
    #expect(
      model.sentMessage
        == "We sent a confirmation link to new.diver@example.com. Open it to finish changing your"
        + " email — it expires in 30 minutes.")
    #expect(session.user?.email == "diver@example.com")
  }

  @Test func theConfirmedAddressShowsOnTheNextReadAndTheSentenceGoes() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = EmailChangeModel(session: session)
    model.setNewEmail("new.diver@example.com")
    await model.send()

    // Confirmed on the web; the screen reads the account when the app comes back.
    server.set("email", "new.diver@example.com")
    try await session.reloadAccount()

    #expect(model.currentEmail == "new.diver@example.com")
    #expect(model.sentMessage == nil)
  }

  @Test func aRefusedAddressIsTheAPIsSentenceAndStaysTyped() async throws {
    let server = try SettingsServer()
    server.fail(
      "POST user/email-change/request",
      with: .json(#"{"detail":"That's already your email address."}"#, status: 400))
    let model = EmailChangeModel(session: try await loaded(server))
    model.setNewEmail("diver@example.com")
    await model.send()
    #expect(model.failure == "That's already your email address.")
    #expect(model.newEmail == "diver@example.com")
    #expect(model.sentMessage == nil)
  }

  @Test(arguments: ["diver", "diver@", "@example.com", "diver@example", "a b@example.com"])
  func anAddressThatIsNoAddressIsRefusedWithoutARequest(text: String) async throws {
    let server = try SettingsServer()
    let model = EmailChangeModel(session: try await loaded(server))
    let before = server.requests.count
    model.setNewEmail(text)
    await model.send()
    #expect(server.requests.count == before)
    #expect(model.failure == EmailChangeModel.invalidAddress)
  }

  @Test func anAddressOfflineSendsNothing() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let session = try await loaded(server, connectivity: connectivity)
    connectivity.isRouteAvailable = false
    let model = EmailChangeModel(session: session)
    let before = server.requests.count
    model.setNewEmail("new.diver@example.com")
    await model.send()
    #expect(server.requests.count == before)
    #expect(model.failure == APIError.noRoute.message)
    #expect(model.newEmail == "new.diver@example.com")
  }
}

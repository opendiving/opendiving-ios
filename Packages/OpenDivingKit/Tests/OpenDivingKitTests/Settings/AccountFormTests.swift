import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// *Account*'s name and username, each on its own screen, and its email.
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

  private func field(_ field: AccountFieldModel.Field, _ session: Session) -> AccountFieldModel {
    AccountFieldModel(field: field, write: AccountWrite(session: session), session: session)
  }

  @Test func eachFieldShowsTheAccountAndNothingIsSavedUntilItChanges() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let name = field(.name, session)
    #expect(name.text == "Test Diver")
    #expect(field(.username, session).text == "testdiver")
    #expect(!name.canSave)
    name.setText("  Test Diver ")
    #expect(name.update == nil)
    #expect(!name.canSave)
  }

  @Test func theChangeIsSentTrimmedAndTheSessionHoldsTheAnswer() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = field(.name, session)
    let before = server.requests.count

    model.setText(" Sam Diver ")
    #expect(model.canSave)
    #expect(await model.save())

    #expect(sent(server, after: before) == ["PATCH user", "GET user"])
    #expect(
      server.requests.first { $0.httpMethod == "PATCH" }?.json
        == (try JSONValue.parse(Data(#"{"name":"Sam Diver"}"#.utf8))))
    #expect(session.user?.name == "Sam Diver")
    #expect(model.text == "Sam Diver")
    #expect(!model.canSave)
  }

  @Test func theUsernameSendsOnlyItself() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = field(.username, session)
    model.setText("samdiver")
    #expect(await model.save())
    #expect(
      server.requests.first { $0.httpMethod == "PATCH" }?.json
        == (try JSONValue.parse(Data(#"{"username":"samdiver"}"#.utf8))))
    #expect(session.user?.username == "samdiver")
  }

  @Test func aSaveWhoseReadFailedShowsOnTheAccountScreensWrite() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let write = AccountWrite(session: session)
    let model = AccountFieldModel(field: .name, write: write, session: session)
    server.fail("GET user", with: .json(#"{"detail":"Down"}"#, status: 500))

    model.setText("Sam Diver")
    #expect(await model.save())

    #expect(session.user?.name == "Test Diver")
    #expect(AccountFieldModel.shown(.name, write: write, session: session) == "Sam Diver")
  }

  @Test func aTakenUsernameIsTheAPIsSentenceAndWhatWasTypedStaysUntilEdited() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PATCH user", with: .json(#"{"detail":"Username not available"}"#, status: 422))
    let model = field(.username, session)
    model.setText("taken")

    #expect(!(await model.save()))

    #expect(model.failure == "Username not available")
    #expect(model.text == "taken")
    #expect(session.user?.username == "testdiver")
    model.setText("taken2")
    #expect(model.failure == nil)
  }

  @Test func theWebsBoundsAreKeptBeforeAnythingIsSent() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let name = field(.name, session)
    let username = field(.username, session)
    let before = server.requests.count

    name.setText("S")
    #expect(name.problem == "Name must be at least 2 characters")
    name.setText(String(repeating: "a", count: 31))
    #expect(name.problem == "Name cannot exceed 30 characters")
    name.setText(String(repeating: "a", count: 30))
    #expect(name.problem == nil)
    name.setText("Sam Diver")
    #expect(name.problem == nil)
    username.setText("Sam")
    #expect(username.problem == "Username can only contain lowercase letters and numbers")
    username.setText(String(repeating: "a", count: 21))
    #expect(username.problem == "Username cannot exceed 20 characters")
    #expect(!username.canSave)
    #expect(!(await username.save()))
    #expect(server.requests.count == before)
  }

  @Test func offlineNothingIsSentAndTheNoConnectionSentenceShowsAtOnce() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let session = try await loaded(server, connectivity: connectivity)
    connectivity.isRouteAvailable = false
    let model = field(.name, session)
    let before = server.requests.count
    model.setText("Sam Diver")

    #expect(!(await model.save()))

    #expect(server.requests.count == before)
    #expect(model.failure == APIError.noRoute.message)
    #expect(model.text == "Sam Diver")
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

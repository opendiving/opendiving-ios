import Foundation
import OpenDivingKit
import Testing

/// Which inbox a file handed to the app lands in, and when it lands in none.
@MainActor
struct InboxIntakeTests {
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("InboxIntakeTests-\(UUID().uuidString)", isDirectory: true)
  private let shared = SharedFiles()
  private let origin = ImportServer.origin

  private func session(_ server: ImportServer, signedIn: Bool = true, activeServer: Bool = true)
    -> Session
  {
    Session(
      transport: server,
      secrets: InMemorySecretStore(signedIn ? [origin.description: "refresh"] : [:]),
      activeOrigin: InMemoryActiveOriginStore(activeServer ? origin : nil),
      background: NoBackgroundExecution(), applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
  }

  private func inbox(_ session: Session, _ account: UUID) -> InboxStore.Contents {
    InboxStore(store: session.store, origin: origin, account: account).load()
  }

  @Test func twoFilesOfOneNameLandAsTwo() async throws {
    let server = try ImportServer()
    let session = session(server)
    try await session.loadAccount()
    let model = InboxModel(session: session)

    let intake = model.receive(
      [try shared.make("dive.fit", bytes: "one"), try shared.make("dive.fit", bytes: "two")],
      moving: true)
    await model.settled()

    #expect(intake == .kept(account: ImportServer.accountA, signedIn: true))
    let files = inbox(session, ImportServer.accountA).files
    #expect(files.map(\.filename) == ["dive.fit", "dive.fit"])
    #expect(Set(files.map(\.id)).count == 2)
    let store = InboxStore(store: session.store, origin: origin, account: ImportServer.accountA)
    #expect(try files.map { String(decoding: try Data(contentsOf: store.url(for: $0)), as: UTF8.self) } == ["one", "two"])
    #expect(server.previews == [["dive.fit", "dive.fit"]])
  }

  @Test func aFileBeforeTheLoadIsMarkedAndMovesToTheAccountTheLoadNames() async throws {
    let server = try ImportServer()
    try await session(server).loadAccount()  // the pointer now names A

    // A relaunch: signed in, the account not loaded yet.
    let session = session(server)
    let model = InboxModel(session: session)
    let intake = model.receive([try shared.make("early.fit")], moving: true)
    await model.settled()

    #expect(intake == .kept(account: ImportServer.accountA, signedIn: true))
    #expect(inbox(session, ImportServer.accountA).files.map(\.receivedBeforeAccountKnown) == [true])
    #expect(server.previews.isEmpty)

    server.signIn(as: ImportServer.accountB)
    try await session.loadAccount()
    model.sessionChanged()
    await model.settled()

    #expect(inbox(session, ImportServer.accountA).files.isEmpty)
    let moved = inbox(session, ImportServer.accountB).files
    #expect(moved.map(\.filename) == ["early.fit"])
    #expect(moved.map(\.receivedBeforeAccountKnown) == [false])
    #expect(server.previews == [["early.fit"]])
  }

  @Test func aLoadNamingTheSameAccountClearsTheMark() async throws {
    let server = try ImportServer()
    try await session(server).loadAccount()
    let session = session(server)
    let model = InboxModel(session: session)
    model.receive([try shared.make("early.fit")], moving: true)

    try await session.loadAccount()
    model.sessionChanged()
    await model.settled()

    #expect(inbox(session, ImportServer.accountA).files.map(\.receivedBeforeAccountKnown) == [false])
    #expect(server.previews.count == 1)
  }

  @Test func withNoPointerYetAFileIsKeptNowhere() async throws {
    let server = try ImportServer()
    let session = session(server)
    let model = InboxModel(session: session)
    let file = try shared.make("first.fit")

    #expect(model.receive([file], moving: true) == .notKept(InboxModel.accountLoadingSentence))
    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(!FileManager.default.fileExists(atPath: session.store.directory(for: origin).path))
  }

  @Test func withNoServerOrNoAccountAFileIsKeptNowhere() async throws {
    let server = try ImportServer()
    let none = InboxModel(session: session(server, activeServer: false))
    #expect(
      none.receive([try shared.make("a.fit")], moving: true)
        == .notKept(InboxModel.noAccountSentence))
    let signedOut = InboxModel(session: session(server, signedIn: false))
    #expect(
      signedOut.receive([try shared.make("a.fit")], moving: true)
        == .notKept(InboxModel.noAccountSentence))
  }

  @Test func signedOutAShareWaitsInTheLastAccountsInbox() async throws {
    let server = try ImportServer()
    try await session(server).loadAccount()
    let session = session(server, signedIn: false)
    let model = InboxModel(session: session)

    let intake = model.receive([try shared.make("boat.fit")], moving: false)
    model.sessionChanged()
    await model.settled()

    #expect(intake == .kept(account: ImportServer.accountA, signedIn: false))
    #expect(inbox(session, ImportServer.accountA).files.map(\.receivedBeforeAccountKnown) == [false])
    #expect(server.previews.isEmpty)
  }

  @Test func aSessionEndingBeforeTheLoadClearsTheMark() async throws {
    let server = try ImportServer()
    try await session(server).loadAccount()
    let model = InboxModel(session: session(server))
    model.receive([try shared.make("early.fit")], moving: true)

    let after = session(server, signedIn: false)
    InboxModel(session: after).sessionChanged()

    #expect(inbox(after, ImportServer.accountA).files.map(\.receivedBeforeAccountKnown) == [false])
  }
}

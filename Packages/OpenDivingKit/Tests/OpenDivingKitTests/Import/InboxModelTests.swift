import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// When the inbox reads, how many previews that costs, and the apply.
@MainActor
struct InboxModelTests {
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("InboxModelTests-\(UUID().uuidString)", isDirectory: true)
  private let shared = SharedFiles()

  /// A session signed in as A with the account loaded.
  private func signedIn(
    _ server: ImportServer, connectivity: any Connectivity = AlwaysReachable()
  ) async throws -> Session {
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: connectivity, applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    try await session.loadAccount()
    return session
  }

  /// A model over a session signed in as A with the account loaded.
  private func loaded(
    _ server: ImportServer, connectivity: any Connectivity = AlwaysReachable()
  ) async throws -> InboxModel {
    let model = InboxModel(session: try await signedIn(server, connectivity: connectivity))
    model.sessionChanged()
    return model
  }

  private func arrive(_ model: InboxModel, _ names: String...) throws {
    model.receive(try names.map { try shared.make($0) }, moving: true)
  }

  @Test func fiveFilesOneAfterAnotherCostOneReadAndTheTapASecond() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)

    for index in 1...5 {
      try arrive(model, "dive-\(index).fit")
      await model.settled()
    }
    #expect(server.previews == [["dive-1.fit"]])
    #expect(model.read?.stale == true)
    #expect(model.importable == nil)

    model.readAgain()
    await model.settled()
    #expect(server.previews.count == 2)
    #expect(server.previews[1] == (1...5).map { "dive-\($0).fit" })
    #expect(model.read?.stale == false)
    #expect(model.importable != nil)
  }

  @Test func aFileArrivingDuringAReadIsCoveredByOneMore() async throws {
    let server = try ImportServer()
    let preview = try KitFixture.text("import-preview")
    let gate = Gate()
    server.answerPreviews { index in
      if index == 0 { await gate.pass() }
      return .json(preview)
    }
    let model = try await loaded(server)

    try arrive(model, "a.fit")
    await gate.untilArrived()
    try arrive(model, "b.fit")
    model.handle(.routeAppeared)
    model.handle(.becameActive)
    await gate.open()
    await model.settled()

    #expect(server.previews == [["a.fit"], ["a.fit", "b.fit"]])
    #expect(model.read?.stale == false)
  }

  @Test func aReadThatNeverReachedTheServerLeavesNothingAndTheNextMomentReads() async throws {
    let server = try ImportServer()
    let preview = try KitFixture.text("import-preview")
    let gate = Gate()
    server.answerPreviews { index in
      guard index > 0 else {
        await gate.pass()
        throw URLError(.notConnectedToInternet)
      }
      return .json(preview)
    }
    let model = try await loaded(server)

    try arrive(model, "a.fit")
    await gate.untilArrived()
    try arrive(model, "b.fit")
    await gate.open()
    await model.settled()
    #expect(server.previews == [["a.fit"]])
    #expect(model.read == nil)

    model.handle(.routeAppeared)
    await model.settled()
    #expect(server.previews == [["a.fit"], ["a.fit", "b.fit"]])
  }

  @Test func aMomentOverAnEmptyInboxReadsNothing() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    model.handle(.routeAppeared)
    model.handle(.becameActive)
    await model.settled()
    #expect(server.previews.isEmpty)
  }

  @Test func aReconnectOverACoveredInboxReadsNothing() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try arrive(model, "a.fit")
    await model.settled()
    for _ in 0..<3 {
      model.handle(.routeAppeared)
      model.handle(.becameActive)
      await model.settled()
    }
    #expect(server.previews.count == 1)
  }

  @Test func aRefusalIsKeptLikeAPreview() async throws {
    let server = try ImportServer()
    server.answerPreviews { _ in
      .json(#"{"detail":"None of these files is one OpenDiving reads."}"#, status: 415)
    }
    let model = try await loaded(server)

    try arrive(model, "notes.txt")
    await model.settled()
    #expect(model.read?.refusal == "None of these files is one OpenDiving reads.")
    #expect(model.importable == nil)

    model.handle(.routeAppeared)
    try arrive(model, "more.txt")
    model.handle(.becameActive)
    await model.settled()
    #expect(server.previews.count == 1)
    #expect(model.read?.stale == true)
  }

  @Test func a429KeepsTheFilesAndItsSentenceAndIsReadAgainOnTheTapAlone() async throws {
    let server = try ImportServer()
    server.answerPreviews { _ in
      .json(#"{"detail":"Too many imports. Try again in an hour."}"#, status: 429)
    }
    let model = try await loaded(server)

    try arrive(model, "a.fit")
    await model.settled()
    #expect(model.read?.refusal == "Too many imports. Try again in an hour.")
    #expect(model.files.count == 1)
    model.handle(.routeAppeared)
    model.sessionChanged()
    await model.settled()
    #expect(server.previews.count == 1)

    model.readAgain()
    await model.settled()
    #expect(server.previews.count == 2)
  }

  @Test func a5xxShowsTheWebsSentence() async throws {
    let server = try ImportServer()
    server.answerPreviews { _ in .json(#"{"detail":"Internal Server Error"}"#, status: 502) }
    let model = try await loaded(server)
    try arrive(model, "a.fit")
    await model.settled()
    #expect(model.read?.refusal == ImportText.readFailed)
  }

  @Test func aRemovalReadsNothingUntilTheTap() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try arrive(model, "a.fit", "b.fit")
    await model.settled()
    #expect(server.previews == [["a.fit", "b.fit"]])

    model.remove(try #require(model.files.first))
    await model.settled()
    #expect(server.previews.count == 1)
    #expect(model.read?.stale == true)

    model.readAgain()
    await model.settled()
    #expect(server.previews.last == ["b.fit"])
  }

  @Test func removingEveryFileLeavesTheInboxUncovered() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try arrive(model, "a.fit")
    await model.settled()
    model.removeAll()
    #expect(model.read == nil)
    #expect(model.files.isEmpty)

    try arrive(model, "b.fit")
    await model.settled()
    #expect(server.previews == [["a.fit"], ["b.fit"]])
  }

  @Test func nothingReadsBeforeTheAccountLoads() async throws {
    let server = try ImportServer()
    let first = try await loaded(server)
    _ = first
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    let model = InboxModel(session: session)
    try arrive(model, "a.fit")
    model.handle(.routeAppeared)
    model.readAgain()
    await model.settled()
    #expect(server.previews.isEmpty)

    try await session.loadAccount()
    model.sessionChanged()
    await model.settled()
    #expect(server.previews == [["a.fit"]])
  }

  @Test func withNoRouteAFileWaitsUnreadAndSaysSoUntilARouteAppears() async throws {
    let server = try ImportServer()
    let route = SwitchedRoute()
    route.isRouteAvailable = false
    let model = try await loaded(server, connectivity: route)
    try arrive(model, "a.fit", "b.uddf")
    await model.settled()
    model.handle(.becameActive)
    await model.settled()
    #expect(server.previews.isEmpty)
    #expect(
      model.waitingForRoute == "2 files waiting; they are read when the server can be reached")

    route.isRouteAvailable = true
    model.handle(.routeAppeared)
    await model.settled()
    #expect(server.previews == [["a.fit", "b.uddf"]])
    #expect(model.waitingForRoute == nil)
  }

  @Test func theTapReadsWithNoRoute() async throws {
    let server = try ImportServer()
    let route = SwitchedRoute()
    route.isRouteAvailable = false
    let model = try await loaded(server, connectivity: route)
    try arrive(model, "a.fit")
    await model.settled()
    #expect(server.previews.isEmpty)

    model.readAgain()
    await model.settled()
    #expect(server.previews == [["a.fit"]])
  }

  @Test func aFileTheBoundsRefuseIsNeverSent() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    let big = try shared.make("huge.fit")
    let handle = try FileHandle(forWritingTo: big)
    try handle.truncate(atOffset: UInt64(ImportBounds.maxDocumentSize + 1))
    try handle.close()
    model.receive([big, try shared.make("small.fit")], moving: true)
    await model.settled()
    #expect(server.previews == [["small.fit"]])
    #expect(model.refusal(for: model.files[0]) != nil)
  }

  // MARK: - Import

  @Test func theApplySendsWhatThePreviewSentAndTheFilesLeave() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try arrive(model, "a.fit", "b.uddf")
    await model.settled()
    let token = try #require(model.importable).token

    model.apply(ImportCheckInChoices())
    await model.settled()

    let parts = try #require(server.applies.first)
    #expect(parts.first?.name == "token")
    #expect(parts.first?.bytes == Data(token.utf8))
    #expect(parts.filter { $0.name == "file" }.map(\.filename) == ["a.fit", "b.uddf"])
    #expect(model.result != nil)
    #expect(model.files.isEmpty)
    #expect(model.read == nil)
  }

  @Test func anAppliedImportReloadsTheListsShown() async throws {
    let server = try ImportServer()
    let session = try await signedIn(server)
    let model = InboxModel(session: session)
    let list = PagedList<DiveListItem>(session: session) { client, page, perPage in
      try await client.dives(page: page, itemsPerPage: perPage)
    }
    await list.load()
    try arrive(model, "a.fit")
    await model.settled()
    #expect(server.routes.filter { $0 == "GET dives" }.count == 1)

    model.apply(ImportCheckInChoices())
    await model.settled()
    await list.reloading?.value
    #expect(server.routes.filter { $0 == "GET dives" }.count == 2)
  }

  @Test func a4xxOnTheApplyKeepsTheFiles() async throws {
    let server = try ImportServer()
    server.answerApply { .json(#"{"detail":"Your storage is full."}"#, status: 413) }
    let model = try await loaded(server)
    try arrive(model, "a.fit")
    await model.settled()

    model.apply(ImportCheckInChoices())
    await model.settled()

    #expect(model.applyError == "Your storage is full.")
    #expect(model.files.count == 1)
    #expect(model.result == nil)
    #expect(server.previews.count == 1)
  }

  @Test func anExpiredPreviewIsReadAgain() async throws {
    let server = try ImportServer()
    server.answerApply {
      .json(
        #"{"detail":"This preview has expired. Preview the files again to import them."}"#,
        status: 422)
    }
    let model = try await loaded(server)
    try arrive(model, "a.fit")
    await model.settled()

    model.apply(ImportCheckInChoices())
    await model.settled()

    #expect(server.previews.count == 2)
    #expect(model.applyError == nil)
    #expect(model.importable != nil)
    #expect(model.files.count == 1)
  }

  @Test func aKeptDetailIsLeftOutOfTheSubmission() throws {
    let details: [ImportCheckInDetail] = [
      .email(account: "old@example.com", proposed: "new@example.com"),
      .phone(account: nil, proposed: "+1 555"),
    ]
    let submission = try #require(ImportCheckInChoices(kept: ["email"]).submission(for: details))
    #expect(submission.email == .absent)
    #expect(submission.phone == .value("+1 555"))
    #expect(ImportCheckInChoices(kept: ["email", "phone"]).submission(for: details) == nil)
    let offer = try APICoding.decoder().decode(
      ImportPortraitOffer.self, from: Data(#"{"account_sha256":null,"proposed":"data:"}"#.utf8))
    #expect(ImportCheckInChoices(portraitKept: true).portrait(for: offer)?.take == false)
  }

  @Test func aReadSurvivesTheDisk() throws {
    let preview = try KitFixture.decode(ImportPreview.self, "import-preview")
    let read = InboxRead(files: [UUID()], preview: preview, stale: true)
    let again = try APICoding.decoder().decode(
      InboxRead.self, from: APICoding.encoder().encode(read))
    #expect(again == read)
  }
}

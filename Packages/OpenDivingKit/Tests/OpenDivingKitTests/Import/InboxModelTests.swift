import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// What goes up and when, what the phone keeps, and the pending import read, applied and
/// discarded.
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

  private func uploaded(_ model: InboxModel, _ names: String...) async throws {
    model.receive(try names.map { try shared.make($0) }, moving: true)
    model.upload()
    await model.settled()
  }

  private func appeared(_ model: InboxModel) async {
    model.readPending()
    await model.settled()
  }

  private func imports(_ server: ImportServer) -> [String] {
    server.routes.filter { $0.contains("import") }
  }

  // MARK: - Nothing goes up on its own

  @Test func noArrivalAccountLoadOrRouteMomentSendsARequest() async throws {
    let server = try ImportServer()
    let session = try await signedIn(server)
    let model = InboxModel(session: session)
    model.sessionChanged()
    try arrive(model, "a.fit")
    model.receive([try shared.make("b.zip")], moving: true)
    model.sessionChanged()
    await model.settled()

    #expect(imports(server).isEmpty)
    #expect(model.files.map(model.stage(of:)) == [.waiting, .waiting])
  }

  @Test func nothingUploadsBeforeTheAccountLoads() async throws {
    let server = try ImportServer()
    _ = try await loaded(server)
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    let model = InboxModel(session: session)
    try arrive(model, "a.fit")
    #expect(!model.canUpload)
    model.upload()
    model.readPending()
    await model.settled()
    #expect(imports(server).isEmpty)
  }

  // MARK: - The upload

  @Test func anUploadSendsEveryWaitingFileOnceAndRecordsTheImportOnEach() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit", "b.uddf")

    #expect(server.uploads == [["a.fit", "b.uddf"]])
    let held = try #require(server.pendingUUID)
    #expect(model.pending?.uuid == held)
    #expect(model.files.map(\.uploadedInto) == [held, held])
    #expect(model.files.map(model.stage(of:)) == [.uploaded, .uploaded])
    #expect(model.waiting.isEmpty)
    #expect(!imports(server).contains("GET imports/pending"))

    // What the phone recorded outlives the model.
    let again = InboxModel(session: try await signedIn(server))
    #expect(again.files.map(\.uploadedInto) == [held, held])
    #expect(again.pending == nil)
  }

  @Test func aFileTheBoundsRefuseIsNeverSent() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    let big = try shared.make("huge.fit")
    let handle = try FileHandle(forWritingTo: big)
    try handle.truncate(atOffset: UInt64(ImportBounds.maxDocumentSize + 1))
    try handle.close()
    model.receive([big, try shared.make("small.fit")], moving: true)
    model.upload()
    await model.settled()

    #expect(server.uploads == [["small.fit"]])
    #expect(model.waiting.map(\.filename) == ["huge.fit"])
    #expect(model.stage(of: model.waiting[0]).isRefused)
  }

  @Test func filesThatCannotGoAsOneImportCannotBeUploaded() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    let zips = try ["a.zip", "b.zip"].map { name in
      let url = try shared.make(name)
      let handle = try FileHandle(forWritingTo: url)
      try handle.truncate(atOffset: UInt64(ImportBounds.maxArchiveSize / 2 + 1))
      try handle.close()
      return url
    }
    model.receive(zips, moving: true)
    #expect(model.selectionRefusal != nil)
    #expect(!model.canUpload)
    model.upload()
    await model.settled()
    #expect(server.uploads.isEmpty)
  }

  @Test func aFileArrivingDuringAnUploadStaysWaiting() async throws {
    let server = try ImportServer()
    let gate = Gate()
    server.answerUploads { _ in
      await gate.pass()
      return nil
    }
    let model = try await loaded(server)
    try arrive(model, "a.fit")
    model.upload()
    await gate.untilArrived()
    #expect(model.phase == .uploading)
    try arrive(model, "b.fit")
    #expect(model.files.map(model.stage(of:)) == [.uploading, .waiting])
    await gate.open()
    await model.settled()

    #expect(server.uploads == [["a.fit"]])
    #expect(model.files.map(model.stage(of:)) == [.uploaded, .waiting])
    #expect(model.phase == .idle)
  }

  @Test func eachFileStandsAsTheServerReadIt() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit", "notes.txt")

    let refusal = "This file is not one OpenDiving reads."
    #expect(model.files.map(model.stage(of:)) == [.uploaded, .refused(refusal)])
    #expect(model.members(of: model.files[0]).own?.name == "a.fit")
    #expect(model.members(of: model.files[1]).own?.refusal == refusal)
  }

  @Test func aConflictKeepsTheFilesWaitingShowsTheSentenceAndReadsThePendingImport() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    let elsewhere = server.holdElsewhere()
    try await uploaded(model, "a.fit")

    #expect(model.waiting.map(\.filename) == ["a.fit"])
    #expect(model.files.first?.uploadedInto == nil)
    #expect(model.uploadError?.contains("is waiting to be finished") == true)
    #expect(model.pending?.uuid == elsewhere)
    #expect(model.uploadHold == ImportText.pendingBlocksUpload)
    #expect(!model.canUpload)
  }

  @Test func anyOtherRefusalKeepsTheFilesWaitingWithItsSentence() async throws {
    let server = try ImportServer()
    server.answerUploads { _ in
      .json(#"{"detail":"Too many imports. Try again in an hour."}"#, status: 429)
    }
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")

    #expect(model.uploadError == "Too many imports. Try again in an hour.")
    #expect(model.waiting.count == 1)
    #expect(model.canUpload)
    #expect(!imports(server).contains("GET imports/pending"))
  }

  @Test func a5xxShowsTheAppsSentence() async throws {
    let server = try ImportServer()
    server.answerUploads { _ in .json(#"{"detail":"Internal Server Error"}"#, status: 502) }
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    #expect(model.uploadError == ImportText.uploadFailed)
  }

  @Test func anUnreachableServerLeavesEverythingAsItWasAndTheNextTapStartsClean() async throws {
    let server = try ImportServer()
    let gate = Gate()
    server.answerUploads { index in
      guard index > 0 else { throw URLError(.notConnectedToInternet) }
      await gate.pass()
      return nil
    }
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    #expect(model.uploadError == ImportText.unreachable)
    #expect(model.waiting.count == 1)
    #expect(model.pending == nil)

    model.upload()
    await gate.untilArrived()
    #expect(model.uploadError == nil)
    await gate.open()
    await model.settled()
    #expect(model.pending != nil)
  }

  @Test func theTapUploadsWithNoRoute() async throws {
    let server = try ImportServer()
    let route = SwitchedRoute()
    route.isRouteAvailable = false
    let model = try await loaded(server, connectivity: route)
    try await uploaded(model, "a.fit")
    #expect(server.uploads == [["a.fit"]])
  }

  // MARK: - What an uploaded file waits for

  @Test func aFileAnImportHoldsCannotBeRemoved() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    try arrive(model, "b.fit")

    model.remove(model.files[0])
    #expect(model.files.count == 2)
    model.removeAll()
    #expect(model.files.map(\.filename) == ["a.fit"])
  }

  @Test func aPending404ThenAppliedRemovesTheFiles() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit", "b.fit")
    let held = try #require(server.pendingUUID)
    let bytes = try #require(url(of: model.files[0], model))
    server.applyElsewhere()

    await appeared(model)

    #expect(
      imports(server).suffix(2) == [
        "GET imports/pending", "GET import/\(held.uuidString.lowercased())",
      ])
    #expect(model.files.isEmpty)
    #expect(model.pending == nil)
    #expect(!FileManager.default.fileExists(atPath: bytes.path))
  }

  @Test func aPending404ThenA404ReturnsTheFilesToWaiting() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit", "b.fit")
    server.discardElsewhere()

    await appeared(model)

    #expect(model.pending == nil)
    #expect(model.files.map(\.uploadedInto) == [nil, nil])
    #expect(model.files.map(model.stage(of:)) == [.waiting, .waiting])
    #expect(model.canUpload)
  }

  @Test func aPendingReadNamingADifferentImportRemovesTheFilesOfOneApplied() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    server.applyElsewhere()
    let next = server.holdElsewhere()

    await appeared(model)

    #expect(model.files.isEmpty)
    #expect(model.pending?.uuid == next)
  }

  @Test func aPendingReadNamingADifferentImportReturnsTheFilesOfOneGone() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    server.discardElsewhere()
    let next = server.holdElsewhere()

    await appeared(model)

    #expect(model.files.map(\.uploadedInto) == [nil])
    #expect(model.pending?.uuid == next)
    #expect(model.uploadHold == ImportText.pendingBlocksUpload)
  }

  @Test func aReadThatFailsLeavesTheFilesAsTheyWere() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    let held = try #require(server.pendingUUID)
    server.discardElsewhere()
    server.beforePendingRead { throw URLError(.notConnectedToInternet) }

    await appeared(model)

    #expect(model.files.map(\.uploadedInto) == [held])
    #expect(model.pending?.uuid == held)
  }

  private func url(of file: InboxFile, _ model: InboxModel) -> URL? { model.url(for: file) }

  // MARK: - The pending import

  @Test func thePendingImportIsReadOnAppearingWhicheverDeviceUploadedIt() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try arrive(model, "a.fit")
    let elsewhere = server.holdElsewhere()

    await appeared(model)

    #expect(model.pending?.uuid == elsewhere)
    #expect(model.files.first?.uploadedInto == nil)
    #expect(model.uploadHold == ImportText.pendingBlocksUpload)
    #expect(!model.canUpload)
  }

  @Test func withNoRouteThePendingImportIsNotRead() async throws {
    let server = try ImportServer()
    let route = SwitchedRoute()
    route.isRouteAvailable = false
    let model = try await loaded(server, connectivity: route)
    await appeared(model)
    #expect(imports(server).isEmpty)
  }

  @Test func anUploadTappedDuringAPendingReadDropsTheRead() async throws {
    let server = try ImportServer()
    let gate = Gate()
    server.beforePendingRead { await gate.pass() }
    let model = try await loaded(server)
    try arrive(model, "a.fit")
    model.readPending()
    await gate.untilArrived()

    model.upload()
    await model.settled()
    let held = try #require(server.pendingUUID)
    await gate.open()
    for _ in 0..<100 { await Task.yield() }

    #expect(model.pending?.uuid == held)
    #expect(model.files.first?.uploadedInto == held)
  }

  // MARK: - Apply and discard

  @Test func theApplySendsNoBytesAndTheFilesLeave() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit", "b.uddf")
    let held = try #require(server.pendingUUID).uuidString.lowercased()
    let sent = try #require(url(of: model.files[0], model))

    model.apply(ImportCheckInChoices())
    await model.settled()

    #expect(imports(server).contains("POST import/\(held)/apply"))
    #expect(try JSONValue.parse(server.applies[0])["check_in_details"]?["email"] != nil)
    #expect(model.result?.isApplied == true)
    #expect(model.pending == nil)
    #expect(model.files.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: sent.path))
    #expect(imports(server).last == "GET imports/pending")

    model.dismissResult()
    #expect(model.result == nil)
  }

  @Test func aKeptDetailIsLeftOutOfTheApply() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    model.apply(ImportCheckInChoices(kept: ["email"]))
    await model.settled()
    #expect(try JSONValue.parse(server.applies[0]) == JSONValue.parse(Data("{}".utf8)))
  }

  @Test func anAppliedImportReloadsTheListsShown() async throws {
    let server = try ImportServer()
    let session = try await signedIn(server)
    let model = InboxModel(session: session)
    let list = PagedList<DiveListItem>(session: session) { client, page, perPage in
      try await client.dives(page: page, itemsPerPage: perPage)
    }
    await list.load()
    try await uploaded(model, "a.fit")
    #expect(server.routes.filter { $0 == "GET dives" }.count == 1)

    model.apply(ImportCheckInChoices())
    await model.settled()
    await list.reloading?.value
    #expect(server.routes.filter { $0 == "GET dives" }.count == 2)
  }

  @Test(arguments: [(413, "Your storage is full."), (429, "Too many imports.")])
  func aRefusedApplyKeepsThePendingImportAndItsSentence(status: Int, detail: String) async throws {
    let server = try ImportServer()
    server.answerApply { .json(#"{"detail":"\#(detail)"}"#, status: status) }
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")

    model.apply(ImportCheckInChoices())
    await model.settled()

    #expect(model.applyError == detail)
    #expect(model.pending != nil)
    #expect(model.files.count == 1)
    #expect(model.result == nil)
    #expect(!imports(server).contains("GET imports/pending"))
  }

  @Test func anApplyAnotherDeviceBeatRereadsAndTheFilesLeave() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    server.applyElsewhere()

    model.apply(ImportCheckInChoices())
    await model.settled()

    #expect(model.applyError == "This import has already been applied.")
    #expect(model.pending == nil)
    #expect(model.files.isEmpty)
    #expect(model.result == nil)
  }

  @Test func anApplyOfAnImportGoneRereadsAndTheFilesWait() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    server.discardElsewhere()

    model.apply(ImportCheckInChoices())
    await model.settled()

    #expect(model.applyError == "Import not found")
    #expect(model.pending == nil)
    #expect(model.files.map(\.uploadedInto) == [nil])
  }

  @Test func aDiscardDeletesThePendingImportAndTheFilesWaitAgain() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")

    model.discard()
    await model.settled()

    #expect(server.discards == ["status=pending"])
    #expect(server.pendingUUID == nil)
    #expect(model.pending == nil)
    #expect(model.files.map(\.uploadedInto) == [nil])
    #expect(model.canUpload)
    #expect(imports(server).last == "GET imports/pending")
  }

  @Test func aDiscardAnotherDeviceBeatRereads() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    server.applyElsewhere()

    model.discard()
    await model.settled()

    #expect(model.applyError == "This import is applied, not pending.")
    #expect(model.pending == nil)
    #expect(model.files.isEmpty)
  }

  @Test func aDiscardOfAnImportGoneRereadsAndTheFilesWait() async throws {
    let server = try ImportServer()
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")
    server.discardElsewhere()

    model.discard()
    await model.settled()

    #expect(model.pending == nil)
    #expect(model.files.map(\.uploadedInto) == [nil])
  }

  @Test func aDiscardThatFailsLeavesThePendingImport() async throws {
    let server = try ImportServer()
    server.answerDiscard { .json(#"{"detail":"Internal Server Error"}"#, status: 500) }
    let model = try await loaded(server)
    try await uploaded(model, "a.fit")

    model.discard()
    await model.settled()

    #expect(model.applyError == "Internal Server Error")
    #expect(model.pending != nil)
    #expect(model.files.first?.uploadedInto != nil)
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

  // MARK: - The store

  private func store() async throws -> InboxStore {
    InboxStore(
      store: try await signedIn(try ImportServer()).store, origin: ImportServer.origin,
      account: ImportServer.accountA)
  }

  @Test func anInboxStoredWithAReadLoadsWithoutIt() async throws {
    let store = try await store()
    let file = InboxFile(filename: "a.fit", byteSize: 1)
    try store.save(InboxStore.Contents(files: [file]))
    let record = store.url(for: file).deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("inbox.json")
    var json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: record)) as? [String: Any])
    json["read"] = ["files": [file.id.uuidString], "stale": false, "preview": ["token": "t"]]
    try JSONSerialization.data(withJSONObject: json).write(to: record)

    #expect(store.load().files == [file])
    try store.save(store.load())
    let saved = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: record)) as? [String: Any])
    #expect(saved["read"] == nil)
  }

  @Test func aDownloadAnEarlierBuildKeptInTheInboxLoadsAsAFileLikeAnyOther() async throws {
    let store = try await store()
    let file = InboxFile(filename: "shearwater-perdix-3_D9772626_2026-10-25T0920.zip", byteSize: 1)
    try store.save(InboxStore.Contents(files: [file]))
    let record = store.url(for: file).deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("inbox.json")
    var json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: record)) as? [String: Any])
    var files = try #require(json["files"] as? [[String: Any]])
    files[0]["download"] = [
      "computers": [
        [
          "family": "shearwater-petrel", "vendor": "Shearwater", "product": "Perdix 3",
          "serial": "D9772626", "dives": 12,
        ]
      ],
      "downloaded_at": "2026-10-25T09:20:00Z",
    ]
    json["files"] = files
    try JSONSerialization.data(withJSONObject: json).write(to: record)

    #expect(store.load().files == [file])
    #expect(store.unreadableCount == 0)
  }

  @Test func aRecordedImportSurvivesTheDisk() async throws {
    let store = try await store()
    let held = UUID()
    try store.save(
      InboxStore.Contents(files: [InboxFile(filename: "a.fit", byteSize: 1, uploadedInto: held)]))
    #expect(store.load().files.map(\.uploadedInto) == [held])
  }
}

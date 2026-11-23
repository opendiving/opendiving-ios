import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The Dive Computers list over the engine, a fake link and the fake import server with its
/// dive-computer routes: the order the list shows and sends, *Which computer comes first?* and
/// the dives it holds, each computer's line, and *Allow notifications*.
@MainActor
struct DiveComputerListTests {
  private typealias F = DiveComputerFixtures

  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("DiveComputerListTests-\(UUID().uuidString)", isDirectory: true)
  private let server: ImportServer
  private let route = SwitchedRoute()
  private let link = FakeDiveComputerLink()
  private let notifier = FakeNotifier()
  private let wake = FakeWake()

  init() throws {
    server = try ImportServer()
  }

  private let ocean = DiveComputerRead(
    serial: "253810000400", brand: "Suunto", model: "Ocean", name: nil, position: 0)

  private func session() async throws -> Session {
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: route, applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    try await session.loadAccount()
    return session
  }

  private func model(_ session: Session) -> (DiveComputerEngine, DiveComputerModel) {
    let link = link
    let engine = DiveComputerEngine(
      session: session, makeLink: { link }, generator: F.generator, notifier: notifier,
      wake: wake, workFolder: root.appendingPathComponent("Work", isDirectory: true),
      now: { F.moment }, zone: F.helsinki)
    engine.accountLoaded()
    return (engine, DiveComputerModel(engine: engine, zone: F.helsinki))
  }

  private func computers(_ session: Session) -> DiveComputerStore {
    DiveComputerStore(
      store: session.store, origin: ImportServer.origin, account: ImportServer.accountA)
  }

  private func pairPerdix(_ model: DiveComputerModel) async throws {
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    model.pair()
    await model.watch()
    for _ in 0..<1000 where model.unpairedRows.isEmpty { await Task.yield() }
    model.connect(try #require(model.unpairedRows.first))
    await model.settled()
  }

  private func until(_ condition: () -> Bool) async {
    for _ in 0..<100_000 where !condition() { await Task.yield() }
  }

  // MARK: - Which computer comes first?

  @Test func aComputerPairedBesideOneOtherWaitsForTheAnswerAndThenGoesUp() async throws {
    let session = try await session()
    server.keepComputers([ocean])
    let (engine, model) = model(session)
    await model.appeared()
    try await pairPerdix(model)

    let question = try #require(model.orderQuestion)
    #expect(question.record.title == "Shearwater Perdix 3")
    #expect(question.other == "Suunto Ocean")
    #expect(server.atOnce.isEmpty)
    #expect(engine.archives.count == 1)
    #expect(notifier.posted.isEmpty)
    #expect(model.status(question.record) == "2 dives waiting to upload")

    await model.answerOrder(newFirst: true)
    await model.settled()
    #expect(server.orders == [["D9772626", "253810000400"]])
    #expect(server.atOnce.count == 1)
    #expect(engine.archives.isEmpty)
    #expect(model.orderQuestion == nil)
  }

  @Test func withNoRouteTheDivesWaitUnsaidAndTheQuestionStands() async throws {
    let session = try await session()
    try computers(session).save(DiveComputerRecord(identity: F.ocean))
    route.isRouteAvailable = false
    let (engine, model) = model(session)
    try await pairPerdix(model)

    #expect(model.orderQuestion?.other == "Suunto Ocean")
    #expect(engine.archives.count == 1)
    #expect(notifier.posted.isEmpty)
    #expect(wake.left.isEmpty)

    await model.answerOrder(newFirst: false)
    #expect(server.orders.isEmpty)
    #expect(model.orderQuestion != nil)

    // Asked again the next time the screen is in front, and answered then.
    route.isRouteAvailable = true
    let (_, again) = self.model(session)
    await again.appeared()
    #expect(again.orderQuestion?.record.title == "Shearwater Perdix 3")
    await again.answerOrder(newFirst: false)
    await again.settled()
    #expect(server.orders == [["253810000400", "D9772626"]])
    #expect(server.atOnce.count == 1)
  }

  @Test func aQuestionAboutAComputerOnlyTheServerKnowsOutlivesTheProcess() async throws {
    let session = try await session()
    server.keepComputers([ocean])
    let (_, model) = model(session)
    await model.appeared()
    try await pairPerdix(model)
    #expect(model.orderQuestion?.other == "Suunto Ocean")

    // A later process, with no route: the order is not read, and the dives keep waiting.
    route.isRouteAvailable = false
    let (offline, unread) = self.model(session)
    await unread.appeared()
    await offline.settled()
    #expect(unread.orderQuestion == nil)
    #expect(offline.archives.count == 1)
    #expect(computers(session).records().first { $0.serial == "D9772626" }?.awaitsOrder == true)

    // With a route, the read names the other computer and the question is asked again.
    route.isRouteAvailable = true
    let (engine, again) = self.model(session)
    await again.appeared()
    #expect(again.orderQuestion?.other == "Suunto Ocean")
    await engine.settled()
    #expect(server.atOnce.isEmpty)
  }

  @Test func pairedWithNoRouteBesideAComputerOnlyTheServerKnowsTheDivesWait() async throws {
    let session = try await session()
    server.keepComputers([ocean])
    route.isRouteAvailable = false
    let (engine, model) = model(session)
    try await pairPerdix(model)
    #expect(model.orderQuestion == nil)

    // The first upload with a route reads the order before anything goes.
    route.isRouteAvailable = true
    engine.upload()
    await engine.settled()
    #expect(server.atOnce.isEmpty)
    // The screen still in front asks it, with no visit of its own.
    #expect(model.orderQuestion?.other == "Suunto Ocean")
    await model.answerOrder(newFirst: false)
    await model.settled()
    #expect(server.orders == [["253810000400", "D9772626"]])
    #expect(server.atOnce.count == 1)
  }

  @Test func aFirstComputerPairedWithNoRouteGoesUpOnceTheOrderIsRead() async throws {
    let session = try await session()
    server.keepComputers([])
    route.isRouteAvailable = false
    let (engine, model) = model(session)
    try await pairPerdix(model)

    route.isRouteAvailable = true
    engine.upload()
    await engine.settled()
    #expect(server.orders.isEmpty)
    #expect(server.atOnce.count == 1)
    #expect(computers(session).records().allSatisfy { !$0.awaitsOrder })
  }

  @Test func anAnswerReadsAnOrderNotReadYetAndSendsItWhole() async throws {
    let session = try await session()
    try computers(session).save(DiveComputerRecord(identity: F.ocean))
    route.isRouteAvailable = false
    let (_, model) = model(session)
    try await pairPerdix(model)
    #expect(model.orderQuestion?.other == "Suunto Ocean")

    // Meanwhile the server learnt a third computer: the question no longer stands.
    server.keepComputers([
      ocean,
      DiveComputerRead(serial: "A1B2", brand: "Shearwater", model: "Teric", name: nil, position: 1),
    ])
    route.isRouteAvailable = true
    await model.answerOrder(newFirst: true)
    await model.settled()
    #expect(server.orders.isEmpty)
    #expect(model.orderQuestion == nil)
    // Released from the question, the dives go up.
    await until { server.atOnce.count == 1 }
    #expect(server.atOnce.count == 1)
  }

  @Test func whatTheDiverSetsDuringTheTimeZoneQuestionOutlivesTheWalk() async throws {
    let session = try await session()
    server.keepComputers([])
    try computers(session).save(DiveComputerRecord(identity: F.perdix))
    let (_, model) = model(session)
    await model.appeared()
    link.found = [F.oceanFound]
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    model.pair()
    await model.watch()
    await until { !model.unpairedRows.isEmpty }
    model.connect(try #require(model.unpairedRows.first))
    await until { model.phase == .askingTimeZone }
    let ocean = try #require(model.orderQuestion?.record)
    #expect(ocean.title == "Suunto Ocean")

    await model.answerOrder(newFirst: false)
    model.setDownloadsAutomatically(false, for: ocean)
    model.answerTimeZone(try #require(TimeZone(identifier: "Asia/Tokyo")))
    await model.settled()

    let saved = try #require(computers(session).record(family: .suuntoNautic, serial: ocean.serial))
    #expect(!saved.awaitsOrder)
    #expect(!saved.downloadsAutomatically)
    #expect(server.orders == [["D9772626", "253810000400"]])
    #expect(server.atOnce.count == 1)
    #expect(model.orderQuestion == nil)
  }

  @Test func aServerWithNoOrderTakesTheAnswerAsSent() async throws {
    let session = try await session()
    try computers(session).save(DiveComputerRecord(identity: F.ocean))
    let (engine, model) = model(session)
    await model.appeared()
    #expect(engine.orderRouteMissing)
    try await pairPerdix(model)

    await model.answerOrder(newFirst: true)
    await model.settled()
    #expect(server.atOnce.count == 1)
    #expect(model.orderQuestion == nil)
    #expect(!model.canReorder)
  }

  @Test func withMoreKnownTheNewComputerGoesLastUnasked() async throws {
    let session = try await session()
    server.keepComputers([
      ocean,
      DiveComputerRead(
        serial: "A1B2", brand: "Shearwater", model: "Teric", name: nil, position: 1),
    ])
    let (engine, model) = model(session)
    await model.appeared()
    try await pairPerdix(model)

    #expect(model.orderQuestion == nil)
    #expect(server.orders.isEmpty)
    // The first dive while the walk runs, the rest at its end.
    #expect(server.atOnce.count == 2)
    #expect(engine.archives.isEmpty)
  }

  @Test func aComputerAlreadyPairedIsNotAskedAbout() async throws {
    let session = try await session()
    server.keepComputers([ocean])
    try computers(session).save(
      DiveComputerRecord(identity: F.perdix, peripheral: F.perdixFound.id))
    let (_, model) = model(session)
    await model.appeared()
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    await model.watch()
    model.download(try #require(model.paired.first?.record), all: false)
    await model.settled()
    #expect(link.downloads == 1)
    #expect(model.orderQuestion == nil)
    #expect(server.atOnce.count == 2)
  }

  // MARK: - The order

  @Test func theListFollowsTheAccountsOrderAndAMoveSendsEverySerialItKnows() async throws {
    let session = try await session()
    try computers(session).save(DiveComputerRecord(identity: F.perdix))
    try computers(session).save(DiveComputerRecord(identity: F.ocean))
    server.keepComputers([
      DiveComputerRead(serial: "A1B2", brand: "Shearwater", model: "Teric", name: nil, position: 0),
      DiveComputerRead(
        serial: "253810000400", brand: "Suunto", model: "Ocean", name: nil, position: 1),
      DiveComputerRead(
        serial: "D9772626", brand: "Shearwater", model: "Perdix 3", name: nil, position: 2),
    ])
    let (_, model) = model(session)
    await model.appeared()
    #expect(model.paired.map(\.title) == ["Suunto Ocean", "Shearwater Perdix 3"])
    #expect(model.canReorder)

    model.move(from: [1], to: 0)
    #expect(model.paired.map(\.title) == ["Shearwater Perdix 3", "Suunto Ocean"])
    await until { !server.orders.isEmpty }
    // The serial the phone has no pairing of keeps its place.
    #expect(server.orders == [["A1B2", "D9772626", "253810000400"]])
  }

  @Test func withoutARouteTheListKeepsItsOrderAndIsNotMoved() async throws {
    let session = try await session()
    try computers(session).save(DiveComputerRecord(identity: F.perdix))
    try computers(session).save(DiveComputerRecord(identity: F.ocean))
    server.keepComputers([
      ocean,
      DiveComputerRead(
        serial: "D9772626", brand: "Shearwater", model: "Perdix 3", name: nil, position: 1),
    ])
    let (_, model) = model(session)
    await model.appeared()
    route.isRouteAvailable = false
    #expect(model.paired.map(\.title) == ["Suunto Ocean", "Shearwater Perdix 3"])
    #expect(!model.canReorder)
    model.move(from: [1], to: 0)
    #expect(model.paired.map(\.title) == ["Suunto Ocean", "Shearwater Perdix 3"])
    #expect(server.orders.isEmpty)
  }

  @Test func forgettingAComputerNoRecordingNamesTakesItOutOfTheOrder() async throws {
    let session = try await session()
    let perdix = DiveComputerRecord(identity: F.perdix)
    try computers(session).save(perdix)
    server.keepComputers([
      DiveComputerRead(serial: "d9772626", brand: nil, model: nil, name: nil, position: 0),
      DiveComputerRead(
        serial: "253810000400", brand: "Suunto", model: "Ocean", name: nil, position: 1),
    ])
    let (_, model) = model(session)
    await model.appeared()
    model.forget(perdix)
    await until { !server.orders.isEmpty }
    #expect(server.orders == [["253810000400"]])
  }

  @Test func forgettingAComputerARecordingNamesLeavesTheOrder() async throws {
    let session = try await session()
    let perdix = DiveComputerRecord(identity: F.perdix)
    try computers(session).save(perdix)
    server.keepComputers([
      DiveComputerRead(
        serial: "D9772626", brand: "Shearwater", model: "Perdix 3", name: nil, position: 0)
    ])
    let (engine, model) = model(session)
    await model.appeared()
    model.forget(perdix)
    await engine.settled()
    #expect(server.orders.isEmpty)
  }

  // MARK: - Each computer's line

  @Test func eachComputersLineIsTheEnginesState() async throws {
    let session = try await session()
    let (engine, model) = model(session)
    var record = DiveComputerRecord(identity: F.perdix)
    #expect(model.status(record) == "No dives downloaded yet")
    record.lastDownloaded = F.moment
    #expect(model.status(record) == "Last downloaded 25 October")
    record.downloadsAutomatically = false
    #expect(model.status(record) == "Automatic download is off")
    record.lastDownloadUnfinished = true
    #expect(model.status(record) == "The last download did not finish")

    let archive = DownloadArchive(
      filename: "a.zip",
      summary: DownloadSummary(
        computers: [
          .init(
            family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3",
            serial: "D9772626", dives: 3)
        ], downloadedAt: F.moment),
      record: record.id, dives: [], receivedBeforeAccountKnown: false)
    let held = DiveComputerEngine.HeldDives(
      id: UUID(), dives: 2, computer: "Shearwater Perdix 3", record: record.id, watchZone: nil)
    #expect(
      DiveComputerStatus.line(record, walk: nil, archives: [archive], held: [])
        == "3 dives waiting to upload")
    #expect(
      DiveComputerStatus.line(record, walk: nil, archives: [archive], held: [held])
        == "Choose a time zone to import 2 dives")

    let walk = DiveComputerWalk(
      computer: F.perdixFound, watched: false, all: false, record: record.id, zone: F.helsinki)
    #expect(
      DiveComputerStatus.line(record, walk: walk, archives: [archive], held: [])
        == DiveComputerText.connecting)
    walk.phase = .downloading
    walk.listing = DiveComputerListing(dives: 11, newDives: 3, sports: nil)
    walk.divesDownloaded = 1
    #expect(
      DiveComputerStatus.line(record, walk: walk, archives: [], held: [])
        == "Downloading 2 of 3 new dives")
    walk.computerBusy = true
    #expect(
      DiveComputerStatus.line(record, walk: walk, archives: [], held: [])
        == "Waiting until this computer is free")
    walk.linkLost = true
    #expect(
      DiveComputerStatus.line(record, walk: walk, archives: [], held: [])
        == "Waiting for this computer to reconnect")
    _ = engine
  }

  @Test func aDownloadThatBrokeOffLeavesTheLineUntilOneFinishes() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    let (_, model) = model(session)
    link.found = [F.perdixFound]
    link.scripts = [
      FakeDiveComputerLink.script(
        F.perdix, Array(F.perdixDownload.prefix(1)), end: .init(.failed(status: "DC_STATUS_IO"))),
      FakeDiveComputerLink.script(F.perdix, F.perdixDownload),
    ]
    model.pair()
    await model.watch()
    for _ in 0..<1000 where model.unpairedRows.isEmpty { await Task.yield() }
    model.connect(try #require(model.unpairedRows.first))
    await model.settled()
    var record = try #require(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626"))
    #expect(record.lastDownloadUnfinished)

    model.download(record, all: false)
    await model.settled()
    record = try #require(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626"))
    #expect(!record.lastDownloadUnfinished)
    #expect(link.opened.last?.computer.id == F.perdixFound.id)
  }

  @Test func theSwitchIsThePairingsAndTheWatchFollowsIt() async throws {
    let session = try await session()
    let record = DiveComputerRecord(identity: F.perdix, peripheral: F.perdixFound.id)
    try computers(session).save(record)
    let (_, model) = model(session)
    await model.appeared()
    model.setDownloadsAutomatically(false, for: record)
    #expect(model.record(record.id)?.downloadsAutomatically == false)
    #expect(
      DiveComputerStore.pairings(applicationSupport: root).first?.downloadsAutomatically == false)
  }

  // MARK: - Notifications

  @Test func notificationsAreOfferedOnceAComputerIsPairedUntilIOSHasAsked() async throws {
    let session = try await session()
    let (_, model) = model(session)
    await model.appeared()
    #expect(!model.offersNotifications)

    try computers(session).save(DiveComputerRecord(identity: F.perdix))
    await model.appeared()
    #expect(model.offersNotifications)
    await model.allowNotifications()
    #expect(notifier.asked == 1)
    #expect(!model.offersNotifications)
  }

  // MARK: - Waiting to Sync

  @Test func waitingToSyncReadsEachArchiveAndTheDivesHeldForAZone() {
    let summary = DownloadSummary(
      computers: [
        .init(
          family: .shearwaterPetrel, vendor: "Shearwater", product: "Perdix 3",
          serial: "D9772626", dives: 3)
      ], downloadedAt: F.moment)
    func archive(_ refusal: DownloadArchive.Refusal?) -> DownloadArchive {
      DownloadArchive(
        filename: "a.zip", summary: summary, record: "r", dives: [],
        receivedBeforeAccountKnown: false, refusal: refusal)
    }
    let held = DiveComputerEngine.HeldDives(
      id: UUID(), dives: 1, computer: "Suunto Ocean", record: nil, watchZone: nil)
    let rows = WaitingDownload.rows(
      archives: [
        archive(nil), archive(.server(message: "This file is too large.")),
        archive(.server(message: nil)), archive(.notAppliedAtOnce),
      ], held: [held])
    #expect(rows.first?.title == "3 dives from Shearwater Perdix 3")
    #expect(
      rows.map(\.stage) == [
        "Waiting to upload", "This file is too large.", "Waiting to upload",
        DiveComputerText.needsNewerServer, "Choose a time zone to import 1 dive",
      ])
    #expect(rows.map(\.refused) == [false, true, false, true, false])
    #expect(rows.map { $0.archive == nil } == [false, false, false, false, true])
    #expect(rows.allSatisfy { $0.lastTry == nil })
  }

  @Test func aDownloadThatWaitsSaysWhatItsLastTryMetAndARefusedOneDoesNot() {
    let summary = DownloadSummary(
      computers: [
        .init(
          family: .suuntoNautic, vendor: "Suunto", product: "Ocean", serial: "253810000400",
          dives: 6)
      ], downloadedAt: F.moment)
    let waiting = DownloadArchive(
      filename: "a.zip", summary: summary, record: "r", dives: [],
      receivedBeforeAccountKnown: false)
    var refused = DownloadArchive(
      filename: "b.zip", summary: summary, record: "r", dives: [],
      receivedBeforeAccountKnown: false)
    refused.refusal = .server(message: "No.")
    let tries = [
      waiting.id: DiveComputerText.lastTry(.http(status: 409, message: "Busy")),
      refused.id: DiveComputerText.lastTry(nil),
    ]
    let rows = WaitingDownload.rows(archives: [waiting, refused], held: [], lastTries: tries)
    #expect(rows.map(\.stage) == ["Waiting to upload", "No."])
    #expect(rows.map(\.lastTry) == ["Last try: the server answered 409", nil])
  }

  @Test func uploadSendsARefusedArchiveAgain() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    let (engine, model) = model(session)
    try await pairPerdix(model)
    let downloads = DownloadStore(
      store: session.store, origin: ImportServer.origin, account: ImportServer.accountA)
    var refused = try #require(downloads.archives().first)
    refused.refusal = .server(message: "No.")
    try downloads.save(refused)
    engine.reload()

    route.isRouteAvailable = true
    engine.upload()
    await engine.settled()
    #expect(server.atOnce.isEmpty)
    engine.sendAgain(refused)
    await engine.settled()
    #expect(server.atOnce.count == 1)
    #expect(engine.archives.isEmpty)
  }

  @Test func removeTakesAWaitingDownloadOffThePhone() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    let (engine, model) = model(session)
    try await pairPerdix(model)
    let archive = try #require(engine.archives.first)
    engine.remove(archive)
    #expect(engine.archives.isEmpty)
    #expect(
      DownloadStore(
        store: session.store, origin: ImportServer.origin, account: ImportServer.accountA
      ).archives().isEmpty)
  }
}

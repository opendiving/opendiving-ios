import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A notifier that keeps what it was given to post.
@MainActor
final class FakeNotifier: DiveComputerNotifier {
  private(set) var posted: [DiveComputerNotice] = []

  func post(_ notice: DiveComputerNotice) { posted.append(notice) }
}

/// A wake that counts the requests left with it.
@MainActor
final class FakeWake: ServerWake {
  private(set) var left: [ServerOrigin] = []

  func leave(for origin: ServerOrigin) { left.append(origin) }
}

/// The engine against a fake watcher, a fake link and the fake import server: a walk nobody
/// starts, the dives it keeps as they arrive, the bounded wait, the held time zone, and each
/// archive's upload applied at once, with the notification its answer makes.
@MainActor
struct DiveComputerEngineTests {
  private typealias F = DiveComputerFixtures

  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("DiveComputerEngineTests-\(UUID().uuidString)", isDirectory: true)
  private let server: ImportServer
  private let route = SwitchedRoute()
  private let link = FakeDiveComputerLink()
  private let watcher = FakeDiveComputerWatcher()
  private let notifier = FakeNotifier()
  private let wake = FakeWake()

  init() throws {
    server = try ImportServer()
  }

  /// A session signed in as A, loaded unless `loaded` is false.
  private func session(loaded: Bool = true) async throws -> Session {
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: route, applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    if loaded { try await session.loadAccount() }
    return session
  }

  /// The engine over the phone's watch, launched with Bluetooth on.
  private func engine(
    _ session: Session, now: Date = DiveComputerFixtures.moment,
    waitLimit: Duration = DiveComputerEngine.automaticWaitLimit,
    loadAccount: @escaping () async -> Void = {}
  ) -> DiveComputerEngine {
    let root = root
    let watch = DiveComputerWatch(
      log: DiveComputerWatchLog(file: root.appendingPathComponent("dive-computer-watch.log")),
      pairings: { DiveComputerStore.pairings(applicationSupport: root) },
      makeWatcher: { [watcher] in watcher }, now: { now })
    let link = link
    let engine = DiveComputerEngine(
      session: session, makeLink: { link }, generator: F.generator, watch: watch,
      notifier: notifier, wake: wake, loadAccount: loadAccount,
      workFolder: root.appendingPathComponent("Work", isDirectory: true), now: { now },
      zone: F.helsinki, waitLimit: waitLimit)
    watch.launched()
    watcher.send(.state(.on, detail: "poweredOn"))
    engine.launched()
    return engine
  }

  private func computers(_ session: Session) -> DiveComputerStore {
    DiveComputerStore(
      store: session.store, origin: ImportServer.origin, account: ImportServer.accountA)
  }

  private func downloads(_ session: Session) -> DownloadStore {
    DownloadStore(store: session.store, origin: ImportServer.origin, account: ImportServer.accountA)
  }

  private func pair(_ session: Session, _ identity: DiveComputerIdentity, at peripheral: UUID)
    throws
  {
    try computers(session).save(DiveComputerRecord(identity: identity, peripheral: peripheral))
  }

  private func until(_ condition: () -> Bool) async {
    for _ in 0..<100_000 where !condition() { await Task.yield() }
  }

  // MARK: - A walk nobody starts

  @Test func aConnectionWalksThePairedComputerAndItsDivesAreImportedAtOnce() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    let engine = engine(session)
    _ = watcher.take()

    watcher.send(.connected(F.perdixFound.id))
    #expect(watcher.take() == [.disarm(F.perdixFound.id)])
    await engine.settled()

    #expect(link.opened.map(\.pairedOnly) == [true])
    #expect(link.opened.first?.computer.id == F.perdixFound.id)
    #expect(link.opened.first?.computer.family == .shearwaterPetrel)
    let sent = try #require(server.atOnce.first)
    #expect(server.atOnce.count == 1)
    #expect(sent.files == ["shearwater-perdix-3_D9772626_2026-10-25T0920.zip"])
    #expect(sent.key != nil)
    #expect(downloads(session).archives().isEmpty)
    #expect(engine.archives.isEmpty)
    #expect(downloads(session).walks().isEmpty)
    let record = try #require(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626"))
    #expect(record.fingerprint == F.fingerprint(3))
    // Answered for, the dives are remembered until the fingerprint next moves.
    #expect(downloads(session).delivered(record.id).count == 2)
    #expect(notifier.posted.map(\.title) == ["1 new dive imported"])
    #expect(watcher.take() == [.arm(F.perdixFound.id, after: DiveComputerWatch.revisitDelay)])
  }

  @Test func aComputerThatAnswersAsOneNotPairedIsClosedUnread() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    // Another computer answers under the paired one's identifier.
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    let engine = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()

    #expect(link.opened.map(\.pairedOnly) == [true])
    #expect(computers(session).record(family: .suuntoNautic, serial: F.ocean.serial) == nil)
    #expect(downloads(session).archives().isEmpty)
    #expect(downloads(session).walks().isEmpty)
    #expect(server.atOnce.isEmpty)
    #expect(notifier.posted.isEmpty)
  }

  @Test func aConnectionInsideTheRevisitDelayOfAnEarlierProcesssWalkStartsNone() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, [])]
    let first = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await first.settled()
    #expect(link.downloads == 1)

    // A new process ten minutes later: its watch knows no visit, the walk's end on disk does.
    _ = watcher.take()
    let later = engine(session, now: F.moment.addingTimeInterval(600))
    _ = watcher.take()
    watcher.send(.connected(F.perdixFound.id))
    await later.settled()
    #expect(link.downloads == 1)
    #expect(watcher.take() == [.disarm(F.perdixFound.id)])

    // Past the delay, a connection walks again.
    let past = engine(session, now: F.moment.addingTimeInterval(1000))
    watcher.send(.connected(F.perdixFound.id))
    await past.settled()
    #expect(link.downloads == 2)
  }

  @Test func oneWalkAtATimeAndATapEndsTheWalkNobodyStarted() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.perdix, at: F.perdixFound.id)
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [
      FakeDiveComputerLink.script(F.perdix, F.perdixDownload),
      FakeDiveComputerLink.script(F.ocean, F.oceanDownload, zone: F.helsinki),
    ]
    link.holdBeforeEnd = true
    let engine = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await until { link.isHeld }
    // A second connection waits its turn.
    watcher.send(.connected(F.oceanFound.id))
    #expect(link.downloads == 1)

    // The diver's tap on the Ocean ends the Perdix's walk with what it kept, and goes first.
    let tapped = try #require(engine.start(F.oceanFound, all: false))
    link.holdBeforeEnd = false
    await engine.settled()
    #expect(link.opened.map(\.computer.id) == [F.perdixFound.id, F.oceanFound.id])
    #expect(link.opened.map(\.pairedOnly) == [true, false])
    #expect(tapped.outcome?.kind == .kept)
    #expect(
      Set(downloads(session).archives().map(\.record))
        == Set(
          [F.perdix, F.ocean].map {
            DiveComputerRecord(identity: $0).id
          }))
    // The Perdix's walk did not complete, so its fingerprint stays where it was.
    #expect(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626")?.fingerprint == nil)
  }

  @Test func aWalkNobodyWatchesEndsAfterTheWaitWithWhatItKept() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let engine = engine(session, waitLimit: .milliseconds(50))
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()

    #expect(link.cancelled)
    #expect(downloads(session).archives().map(\.summary.dives) == [2])
    #expect(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626")?.fingerprint == nil)
  }

  @Test func eachDiveIsOnDiskAsItArrivesAndTheNextLaunchMakesThemAnArchive() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let engine = engine(session)
    var kept = 0
    engine.diveKept = { kept += 1 }
    watcher.send(.connected(F.perdixFound.id))
    await until { link.isHeld }
    await until { kept == 3 }
    let walk = try #require(downloads(session).walks().first)
    #expect(walk.dives.count == 3)
    #expect(downloads(session).dives(of: walk) == F.perdixDownload)
    #expect(downloads(session).archives().isEmpty)

    // The process ends here; the next launch finds the walk and makes its archive.
    let next = DiveComputerEngine(
      session: session, makeLink: { FakeDiveComputerLink() }, generator: F.generator,
      workFolder: root.appendingPathComponent("Next", isDirectory: true), now: { F.moment },
      zone: F.helsinki)
    next.launched()
    #expect(downloads(session).walks().isEmpty)
    let archive = try #require(downloads(session).archives().first)
    #expect(archive.summary.dives == 2)
    #expect(archive.record == DiveComputerRecord(identity: F.perdix).id)
    // Its dives are ones the next walk does not take again.
    #expect(downloads(session).waitingDives(marked: false).count == 2)
    link.release()
    await engine.settled()
  }

  @Test func aDiveTheServerAnsweredForIsNotDownloadedAgainButDownloadAllTakesIt() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [
      FakeDiveComputerLink.script(F.perdix, F.perdixDownload, end: .init(.cancelled)),
      FakeDiveComputerLink.script(F.perdix, []),
    ]
    let engine = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()
    #expect(server.atOnce.count == 1)
    #expect(downloads(session).archives().isEmpty)

    let next = engine.start(F.perdixFound, all: false)
    await engine.settled()
    #expect(next?.outcome != nil)
    let notAgain = try #require(link.waitingTests.last)
    #expect(notAgain(F.perdix, F.fingerprint(3)))
    #expect(notAgain(F.perdix, F.fingerprint(2)))

    engine.start(F.perdixFound, all: true)
    await engine.settled()
    let all = try #require(link.waitingTests.last)
    #expect(!all(F.perdix, F.fingerprint(3)))
  }

  // MARK: - The time zone

  @Test func aWalkNobodyWatchesHoldsTheDivesThatNeedAZoneAndTheScreenAsks() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    let engine = engine(session)
    watcher.send(.connected(F.oceanFound.id))
    await engine.settled()

    #expect(downloads(session).archives().isEmpty)
    #expect(engine.held.map(\.dives) == [2])
    #expect(engine.held.first?.computer == "Suunto Ocean")
    #expect(notifier.posted.map(\.title) == ["Choose a time zone to import 2 dives"])
    #expect(
      notifier.posted.first?.body
        == "Downloaded from Suunto Ocean. Tap to choose the time zone and import them.")
    #expect(notifier.posted.first?.target == .diveComputers)
    // The fingerprint moves: the dives are kept on the phone.
    #expect(
      computers(session).record(family: .suuntoNautic, serial: F.ocean.serial)?.fingerprint
        == F.oceanDownload.first?.fingerprint)

    let model = DiveComputerModel(engine: engine, zone: F.helsinki)
    #expect(model.phase == .askingTimeZone)
    #expect(model.suggestedZone == F.helsinki)
    model.answerTimeZone(try #require(TimeZone(identifier: "Asia/Tokyo")))
    await engine.settled()
    #expect(engine.held.isEmpty)
    let archive = try #require(downloads(session).archives().first)
    let reader = try ZipReader(downloads(session).url(for: archive))
    let entry = try #require(reader.entries.first { $0.name == "logbook.divejson" })
    let json = try #require(ArchiveJSON.parse(try reader.read(entry)))
    #expect(
      json["dives"]?.arrayValue?.map { $0["started_at"]?.stringValue } == [
        "2026-10-26T19:00:00+09:00", "2026-10-24T19:00:00+09:00",
      ])
    #expect(model.phase != .askingTimeZone)
  }

  @Test func answeringTheHeldDivesLeavesTheScreenScanning() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    link.found = [F.oceanFound]
    let engine = engine(session)
    watcher.send(.connected(F.oceanFound.id))
    await engine.settled()

    let model = DiveComputerModel(engine: engine, zone: F.helsinki)
    await model.watch()
    #expect(model.phase == .askingTimeZone)
    model.answerTimeZone(try #require(TimeZone(identifier: "Asia/Tokyo")))
    #expect(model.phase == .scanning)
    await until { !model.rows.isEmpty }
    #expect(model.rows.map(\.computer) == [F.oceanFound])
    await engine.settled()
  }

  @Test func theNextLaunchAsksForTheZoneOfTheDivesAnEndedWalkHeld() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    link.holdBeforeEnd = true
    let engine = engine(session)
    var kept = 0
    engine.diveKept = { kept += 1 }
    watcher.send(.connected(F.oceanFound.id))
    await until { kept == 2 }

    // The process ends here; the next one holds the dives and asks, once.
    let next = DiveComputerEngine(
      session: session, makeLink: { FakeDiveComputerLink() }, generator: F.generator,
      notifier: notifier, workFolder: root.appendingPathComponent("Next", isDirectory: true),
      now: { F.moment }, zone: F.helsinki)
    next.launched()
    #expect(next.held.map(\.dives) == [2])
    #expect(notifier.posted.map(\.title) == ["Choose a time zone to import 2 dives"])
    next.launched()
    #expect(notifier.posted.count == 1)
    link.release()
    await engine.settled()
  }

  @Test func heldDivesAreAnsweredOnceAndKeptWhereTheirArchiveCannotBe() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    let engine = engine(session)
    watcher.send(.connected(F.oceanFound.id))
    await engine.settled()
    let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))

    // An archive that cannot be kept leaves the held dives, their only copy, where they were.
    let archives = downloads(session).root.appendingPathComponent("Archives")
    try Data().write(to: archives)
    engine.answerHeld(tokyo)
    #expect(engine.held.isEmpty)
    await engine.settled()
    #expect(engine.held.map(\.dives) == [2])
    #expect(downloads(session).walks().map(\.dives.count) == [2])

    // Answered twice before the first is written, one archive is.
    try FileManager.default.removeItem(at: archives)
    engine.answerHeld(tokyo)
    engine.answerHeld(tokyo)
    await engine.settled()
    #expect(downloads(session).archives().count == 1)
    #expect(downloads(session).walks().isEmpty)
    #expect(engine.held.isEmpty)
  }

  @Test func heldDivesWhoseBytesAreGoneLeaveWithTheAnswer() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    let engine = engine(session)
    watcher.send(.connected(F.oceanFound.id))
    await engine.settled()
    let walk = try #require(downloads(session).walks().first)
    try FileManager.default.removeItem(at: downloads(session).folder(of: walk.id))

    engine.answerHeld(try #require(TimeZone(identifier: "Asia/Tokyo")))
    await engine.settled()
    #expect(engine.held.isEmpty)
    #expect(downloads(session).walks().isEmpty)
    #expect(downloads(session).archives().isEmpty)
  }

  @Test func theDivesUnderADayOldGoOnWithTheWatchsZoneAndTheOlderWait() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload, zone: F.helsinki)]
    // A day and a half after the older dive, half a day after the newer.
    let engine = engine(session, now: F.moment.addingTimeInterval(30 * 60 * 60))
    watcher.send(.connected(F.oceanFound.id))
    await engine.settled()
    #expect(downloads(session).archives().map(\.summary.dives) == [1])
    #expect(engine.held.map(\.dives) == [1])
  }

  // MARK: - The upload

  private func walked(_ session: Session, route available: Bool = true) async throws
    -> DiveComputerEngine
  {
    route.isRouteAvailable = available
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    let engine = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()
    return engine
  }

  @Test func withNoRouteTheDivesWaitTheDiverIsToldOnceAndIOSIsLeftAWake() async throws {
    let session = try await session()
    let engine = try await walked(session, route: false)
    #expect(server.atOnce.isEmpty)
    #expect(engine.archives.count == 1)
    #expect(notifier.posted.map(\.title) == ["2 dives downloaded"])
    #expect(
      notifier.posted.first?.body
        == "No internet. The dives from Shearwater Perdix 3 will be imported when the phone is"
        + " online again.")
    #expect(wake.left == [ImportServer.origin])

    engine.upload()
    await engine.settled()
    #expect(notifier.posted.count == 1)

    route.isRouteAvailable = true
    engine.upload()
    await engine.settled()
    #expect(server.atOnce.count == 1)
    #expect(engine.archives.isEmpty)
    #expect(notifier.posted.map(\.title) == ["2 dives downloaded", "1 new dive imported"])
  }

  @Test func offlineInAProcessThatHasNotLoadedTheAccountTheDiverIsToldAndIOSLeftAWake()
    async throws
  {
    // An earlier load left the pointer; this process has not loaded the account.
    _ = try await session()
    let fresh = try await session(loaded: false)
    route.isRouteAvailable = false
    try pair(fresh, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    var loads = 0
    let engine = engine(fresh) { loads += 1 }
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()
    #expect(engine.archives.map(\.receivedBeforeAccountKnown) == [true])
    #expect(notifier.posted.map(\.title) == ["2 dives downloaded"])
    #expect(wake.left == [ImportServer.origin])
    #expect(loads == 0)
  }

  @Test func withNothingWaitingNoWakeIsLeft() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    let engine = engine(session)
    engine.upload()
    await engine.settled()
    #expect(wake.left.isEmpty)
  }

  @Test func aWalkNobodyStartedStopsTheScreensScanUntilItEnds() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let engine = engine(session)
    let model = DiveComputerModel(engine: engine, zone: F.helsinki)
    await model.watch()
    #expect(model.phase == .scanning)

    watcher.send(.connected(F.perdixFound.id))
    await until { link.isHeld }
    #expect(model.phase == .idle)
    link.release()
    await engine.settled()
    #expect(model.phase == .scanning)
  }

  @Test func aRetryGoesUnderTheSameKeyAndTheDiverIsToldOnce() async throws {
    let session = try await session()
    server.answerAtOnce { index in
      index == 0 ? .json(#"{"detail":"Server error"}"#, status: 503) : nil
    }
    let engine = try await walked(session)
    #expect(engine.archives.count == 1)
    #expect(engine.archives.first?.refusal == nil)
    #expect(notifier.posted.isEmpty)

    engine.upload()
    await engine.settled()
    engine.upload()
    await engine.settled()
    let keys = server.atOnce.map(\.key)
    #expect(keys.count == 2)
    #expect(Set(keys).count == 1)
    #expect(engine.archives.isEmpty)
    #expect(notifier.posted.map(\.title) == ["1 new dive imported"])
  }

  @Test(arguments: [409, 429, 500])
  func aConflictABudgetOrAServerErrorIsTriedAgainLater(status: Int) async throws {
    let session = try await session()
    server.answerAtOnce { _ in .json(#"{"detail":"Try later"}"#, status: status) }
    let engine = try await walked(session)
    #expect(engine.archives.count == 1)
    #expect(engine.archives.first?.refusal == nil)
    engine.upload()
    await engine.settled()
    #expect(server.atOnce.count == 2)
  }

  @Test func aRefusalIsKeptWithItsSentenceAndNotSentAgainByItself() async throws {
    let session = try await session()
    server.answerAtOnce { _ in
      .json(#"{"detail":"This archive is not one OpenDiving reads."}"#, status: 422)
    }
    let engine = try await walked(session)
    #expect(
      engine.archives.first?.refusal
        == .server(message: "This archive is not one OpenDiving reads."))
    engine.upload()
    await engine.settled()
    #expect(server.atOnce.count == 1)
    #expect(notifier.posted.isEmpty)
  }

  @Test func anImportSinceDeletedTakesTheArchiveOffThePhoneAndSaysNothing() async throws {
    let session = try await session()
    server.answerAtOnce { _ in .json(#"{"detail":"Deleted"}"#, status: 410) }
    let engine = try await walked(session)
    #expect(engine.archives.isEmpty)
    #expect(downloads(session).archives().isEmpty)
    #expect(notifier.posted.isEmpty)
  }

  @Test func aServerThatCannotApplyAtOnceIsAskedToDiscardThePendingImport() async throws {
    let session = try await session()
    server.ignoreApply()
    let engine = try await walked(session)
    #expect(server.uploads.count == 1)
    #expect(server.discards == ["status=pending"])
    #expect(server.pendingUUID == nil)
    #expect(engine.archives.first?.refusal == .notAppliedAtOnce)
    #expect(notifier.posted.isEmpty)
  }

  @Test func signedOutTheDivesWaitForASignInAndTheDiverIsToldOnce() async throws {
    // An earlier load left the pointer the walk keeps for; this process has no session.
    _ = try await session()
    let session = Session(
      transport: server, secrets: InMemorySecretStore([:]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: route, applicationSupport: root,
      userAgent: ClientHarness.userAgent)
    let engine = try await walked(session)
    #expect(engine.archives.count == 1)
    #expect(server.atOnce.isEmpty)
    #expect(notifier.posted.map(\.title) == ["Sign in to import 2 dives"])
    #expect(
      notifier.posted.first?.body
        == "Downloaded from Shearwater Perdix 3. The dives stay on this phone until you sign in.")
    engine.upload()
    await engine.settled()
    #expect(notifier.posted.count == 1)
  }

  @Test func aProcessWhoseAccountHasNotLoadedLoadsItQuietlyFirst() async throws {
    let session = try await session(loaded: false)
    // An earlier load left the pointer the walk keeps for.
    try await session.loadAccount()
    let fresh = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: route, applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    try pair(fresh, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    var loads = 0
    let engine = engine(fresh) {
      loads += 1
      try? await fresh.loadAccount()
    }
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()
    #expect(loads >= 1)
    #expect(server.atOnce.count == 1)
    #expect(engine.archives.isEmpty)
  }

  @Test func nothingIsSaidOfAWalkThatFoundNothingNew() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, [])]
    let engine = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()
    #expect(server.atOnce.isEmpty)
    #expect(notifier.posted.isEmpty)
  }
}

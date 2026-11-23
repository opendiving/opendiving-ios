import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A notifier that keeps what it was given to post, and counts the times it asked.
@MainActor
final class FakeNotifier: DiveComputerNotifier {
  private(set) var posted: [DiveComputerNotice] = []
  private(set) var asked = 0

  func post(_ notice: DiveComputerNotice) { posted.append(notice) }
  func hasAsked() async -> Bool { asked > 0 }
  func ask() async { asked += 1 }
}

/// A clock a test moves on, and what sleeps on it: a sleep returns once the clock reads its end,
/// or throws when its task is cancelled.
final class MovingClock: Sendable {
  private struct State {
    var now: Date
    var sleepers: [UUID: (end: Date, wake: CheckedContinuation<Void, any Error>)] = [:]
  }

  private let state: Mutex<State>

  init(_ start: Date) { state = Mutex(State(now: start)) }

  var now: Date { state.withLock { $0.now } }

  /// How many sleeps wait on the clock.
  var sleeping: Int { state.withLock { $0.sleepers.count } }

  func pass(_ seconds: TimeInterval) {
    let due = state.withLock { state in
      state.now += seconds
      let due = state.sleepers.filter { $0.value.end <= state.now }
      for id in due.keys { state.sleepers[id] = nil }
      return due.values.map(\.wake)
    }
    for wake in due { wake.resume() }
  }

  func sleep(until end: Date) async throws {
    let id = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (wake: CheckedContinuation<Void, any Error>) in
        let due = state.withLock { state in
          if Task.isCancelled { return false }
          guard end > state.now else { return true }
          state.sleepers[id] = (end, wake)
          return false
        }
        if due {
          wake.resume()
        } else if Task.isCancelled {
          wake.resume(throwing: CancellationError())
        }
      }
    } onCancel: {
      let wake = state.withLock { $0.sleepers.removeValue(forKey: id)?.wake }
      wake?.resume(throwing: CancellationError())
    }
  }
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

  /// The engine over the phone's watch, launched with Bluetooth on; `clock`, where given, is the
  /// time instead of `now`.
  private func engine(
    _ session: Session, now: Date = DiveComputerFixtures.moment,
    clock: MovingClock? = nil,
    waitLimit: Duration = DiveComputerEngine.automaticWaitLimit,
    loadAccount: @escaping () async -> Void = {}, handOvers: URL? = nil
  ) -> DiveComputerEngine {
    let root = root
    let time: @Sendable () -> Date
    // A fixed time never turns: a sleep on it waits until its task is cancelled.
    let sleep: @Sendable (Date) async throws -> Void
    if let clock {
      time = { clock.now }
      sleep = { try await clock.sleep(until: $0) }
    } else {
      time = { now }
      sleep = { _ in try await Task.sleep(for: .seconds(24 * 60 * 60)) }
    }
    let watch = DiveComputerWatch(
      log: DiveComputerWatchLog(file: watchLog),
      pairings: { DiveComputerStore.pairings(applicationSupport: root) },
      makeWatcher: { [watcher] in watcher }, handOvers: handOvers, now: time)
    let link = link
    let engine = DiveComputerEngine(
      session: session, makeLink: { link }, generator: F.generator, watch: watch,
      notifier: notifier, wake: wake, loadAccount: loadAccount,
      workFolder: root.appendingPathComponent("Work", isDirectory: true), now: time,
      zone: F.helsinki, waitLimit: waitLimit, sleep: sleep)
    watch.launched()
    watcher.send(.state(.on, detail: "poweredOn"))
    engine.launched()
    return engine
  }

  private var watchLog: URL { root.appendingPathComponent("dive-computer-watch.log") }

  /// The watch log's lines, without their times.
  private func watchLines() -> [String] {
    let text = (try? String(contentsOf: watchLog, encoding: .utf8)) ?? ""
    return text.split(separator: "\n").map { String($0.split(separator: " ", maxSplits: 1)[1]) }
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

  @Test func aConnectionWalksThePairedComputerAndItsDivesAreImportedAsTheyArrive() async throws {
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
    // The first dive goes while the walk runs, and the rest, inside the floor, at its end.
    #expect(server.atOnce.count == 2)
    #expect(
      server.atOnce.map(\.files)
        == Array(
          repeating: ["shearwater-perdix-3_D9772626_2026-10-25T0920.zip"], count: 2))
    #expect(Set(server.atOnce.compactMap(\.key)).count == 2)
    #expect(downloads(session).archives().isEmpty)
    #expect(engine.archives.isEmpty)
    #expect(downloads(session).walks().isEmpty)
    let record = try #require(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626"))
    #expect(record.fingerprint == F.fingerprint(3))
    // The fingerprint passes what was answered for before it moved; the last archive's dive,
    // answered after, is remembered until it next moves.
    #expect(
      downloads(session).delivered(record.id)
        == [DiveComputerArchive.diveUUID(F.perdix, fingerprint: F.fingerprint(2))])
    // One notice for the download, counting both imports' rows.
    #expect(notifier.posted.map(\.title) == ["2 new dives imported"])
    #expect(watcher.take() == [.arm(F.perdixFound.id, after: DiveComputerWatch.revisitDelay)])
  }

  @Test func eachAppliedImportHasTheListsOverTheAccountReadAgain() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    let list = PagedList(session: session) { client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage)
    }
    await list.load()
    let reads = { server.routes.filter { $0 == "GET dives" }.count }
    #expect(reads() == 1)

    let engine = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()
    #expect(server.atOnce.count == 2)
    await until { reads() == 3 }
    #expect(reads() == 3)
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

  @Test func aWalkThatBreaksOffIsTriedAgainSoonerEachTimeLongerUntilOneCompletes() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    let unreachable: [DiveComputerDownloadEvent] = [.finished(.init(.unreachable))]
    link.scripts = [
      unreachable,
      FakeDiveComputerLink.script(F.perdix, [], end: .init(.failed(status: "DC_STATUS_NODEVICE"))),
      FakeDiveComputerLink.script(F.perdix, []),
      unreachable,
    ]
    let clock = MovingClock(F.moment)
    let engine = engine(session, clock: clock)
    func pass(_ seconds: TimeInterval) { clock.pass(seconds) }
    // A walk takes the connection from the watch, which asks again once it ends.
    func walked() async -> [FakeDiveComputerWatcher.Call] {
      _ = watcher.take()
      watcher.send(.connected(F.perdixFound.id))
      await engine.settled()
      return watcher.take()
    }
    func armed(after seconds: Int) -> [FakeDiveComputerWatcher.Call] {
      [.disarm(F.perdixFound.id), .arm(F.perdixFound.id, after: seconds)]
    }
    let perdix = "Shearwater Perdix 3 \(F.perdixFound.id.uuidString)"

    #expect(await walked() == armed(after: 60))
    #expect(link.downloads == 1)
    #expect(
      watchLines().suffix(2) == ["walk ended \(perdix): unreachable", "armed \(perdix) after 60 s"])

    // Inside the minute, a connection is closed and asked again after the same wait.
    pass(30)
    #expect(await walked() == [.disarm(F.perdixFound.id)])
    #expect(link.downloads == 1)
    #expect(watchLines().last == "closing \(perdix), the next request after 60 s")
    watcher.send(.disconnected(F.perdixFound.id, reason: nil))
    #expect(watcher.take() == [.arm(F.perdixFound.id, after: 60)])

    // A minute later it is walked, and breaking off again doubles the wait.
    pass(60)
    #expect(await walked() == armed(after: 120))
    #expect(link.downloads == 2)

    // A walk that completes restores the revisit delay.
    pass(120)
    #expect(await walked() == armed(after: DiveComputerWatch.revisitDelay))
    #expect(link.downloads == 3)

    // And the next break-off starts at a minute again.
    pass(Double(DiveComputerWatch.revisitDelay))
    #expect(await walked() == armed(after: 60))
    #expect(link.downloads == 4)
  }

  @Test func aWalkTheDiverStartedThatFailsKeepsTheRevisitDelay() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [[.finished(.init(.unreachable))]]
    let engine = engine(session)
    _ = watcher.take()
    engine.start(F.perdixFound, all: false)
    await engine.settled()
    #expect(watcher.take().last == .arm(F.perdixFound.id, after: DiveComputerWatch.revisitDelay))
  }

  // MARK: - A lost link

  /// Waits for the fake's hold after the lost link, however many turns that takes, since a release
  /// sent before it would reach nothing; then until the engine has taken the lost link in.
  private func heldLost(_ walk: DiveComputerWalk) async {
    await link.untilHeld()
    await until { walk.linkLost }
  }

  /// A Perdix whose *Download automatically* is off, so only a hand-over arms it.
  private func pairUnwatched(_ session: Session) throws {
    var record = DiveComputerRecord(identity: F.perdix, peripheral: F.perdixFound.id)
    record.downloadsAutomatically = false
    try computers(session).save(record)
  }

  /// The diver's Perdix walk, dropping the link after its first dive and held there until the
  /// return.
  private func lostAfterTheFirstDive() {
    link.scripts = [
      [
        .identified(F.perdix), .listing(.init(dives: 2, newDives: 2)),
        .dive(F.perdixDownload[0]), .linkLost, .linkBack, .dive(F.perdixDownload[1]),
        .finished(.init(.complete)),
      ]
    ]
    link.holdBefore = 4
  }

  @Test func inFrontTheLinkReopensTheComputerItselfAndTheWalkCarriesOn() async throws {
    let session = try await session()
    try pairUnwatched(session)
    lostAfterTheFirstDive()
    let engine = engine(session)
    _ = watcher.take()
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await heldLost(walk)
    #expect(link.opened.map(\.waitsForLink) == [true])
    #expect(watcher.take() == [])
    #expect(link.returns == 0)

    link.release()
    await engine.settled()
    #expect(!walk.linkLost)
    #expect(walk.outcome?.kind == .kept)
    #expect(walk.divesDownloaded == 2)
  }

  @Test func aWalkNobodyStartedDoesNotWaitForALostLink() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    let engine = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()
    #expect(link.opened.map(\.waitsForLink) == [false])
  }

  @Test func behindTheWalkIsHandedToTheWatchWhateverTheSwitchAndItsConnectionReopens()
    async throws
  {
    let session = try await session()
    try pairUnwatched(session)
    lostAfterTheFirstDive()
    let engine = engine(session)
    _ = watcher.take()
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await heldLost(walk)

    engine.foregroundChanged(false)
    #expect(link.foregrounds.last == false)
    // Nothing was watched, so the hand-over makes the central.
    #expect(watcher.take() == [.start])
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(watcher.take() == [.arm(F.perdixFound.id, after: 0)])
    #expect(watchLines().contains { $0.hasPrefix("handed over Shearwater Perdix 3") })

    // iOS connects the computer: the walk reopens it, the watch's connection closed.
    watcher.send(.connected(F.perdixFound.id))
    #expect(link.returns == 1)
    #expect(watcher.take() == [.disarm(F.perdixFound.id)])
    link.release()
    await engine.settled()
    #expect(walk.outcome?.kind == .kept)
    #expect(walk.divesDownloaded == 2)
    #expect(notifier.posted.count == 1)
    // The hand-over was one request: the switch being off, nothing is armed after the walk.
    #expect(watcher.take() == [])
  }

  @Test func backInFrontBeforeTheComputerReturnsTheRequestIsWithdrawn() async throws {
    let session = try await session()
    try pairUnwatched(session)
    lostAfterTheFirstDive()
    let engine = engine(session)
    _ = watcher.take()
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await heldLost(walk)
    engine.foregroundChanged(false)
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(watcher.take() == [.start, .arm(F.perdixFound.id, after: 0)])

    engine.foregroundChanged(true)
    #expect(link.foregrounds.last == true)
    #expect(watcher.take() == [.disarm(F.perdixFound.id)])
    #expect(watchLines().contains { $0.hasPrefix("taken back Shearwater Perdix 3") })
    link.release()
    await engine.settled()
    #expect(link.returns == 0)
    #expect(walk.outcome?.kind == .kept)
  }

  @Test func aCancelDuringTheWaitKeepsTheDivesDownloaded() async throws {
    let session = try await session()
    try pairUnwatched(session)
    link.scripts = [
      [
        .identified(F.perdix), .listing(.init(dives: 2, newDives: 2)),
        .dive(F.perdixDownload[0]), .linkLost, .finished(.init(.complete)),
      ]
    ]
    link.holdBefore = 4
    let engine = engine(session)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await heldLost(walk)
    engine.foregroundChanged(false)
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(watcher.take().last == .arm(F.perdixFound.id, after: 0))

    engine.cancel(walk)
    await engine.settled()
    #expect(walk.outcome?.sentence == "The download was cancelled. 1 dive downloaded.")
    #expect(server.atOnce.count == 1)
    // The walk's end ends the hand-over with it.
    #expect(watcher.take() == [.disarm(F.perdixFound.id)])
  }

  @Test func aHandOverOutlivesTheProcessAndItsConnectionWalksWhateverTheWait() async throws {
    let session = try await session()
    try pairUnwatched(session)
    lostAfterTheFirstDive()
    let handOvers = root.appendingPathComponent("dive-computer-hand-overs.json")
    let first = engine(session, handOvers: handOvers)
    let walk = try #require(first.start(F.perdixFound, all: false))
    await heldLost(walk)
    first.foregroundChanged(false)
    watcher.send(.state(.on, detail: "poweredOn"))
    #expect(watcher.take().last == .arm(F.perdixFound.id, after: 0))
    // The process ends here, mid-walk; an earlier walk ended a minute ago.
    WalkEnds(applicationSupport: root).ended(
      DiveComputerRecord(identity: F.perdix).id, at: F.moment.addingTimeInterval(-60),
      brokeOff: false)

    let next = FakeDiveComputerWatcher()
    let watch = DiveComputerWatch(
      log: DiveComputerWatchLog(file: watchLog),
      pairings: { [root] in DiveComputerStore.pairings(applicationSupport: root) },
      makeWatcher: { next }, handOvers: handOvers, now: { F.moment })
    let later = FakeDiveComputerLink()
    later.scripts = [FakeDiveComputerLink.script(F.perdix, [F.perdixDownload[1]])]
    let engine = DiveComputerEngine(
      session: session, makeLink: { later }, generator: F.generator, watch: watch,
      notifier: notifier, wake: wake,
      workFolder: root.appendingPathComponent("Work", isDirectory: true), now: { F.moment },
      zone: F.helsinki)
    watch.launched()
    next.send(.restored(F.perdixFound.id, .pending))
    next.send(.state(.on, detail: "poweredOn"))
    engine.launched()
    // The restored request is kept, though the computer is not watched.
    #expect(next.take() == [.start])

    next.send(.connected(F.perdixFound.id))
    await engine.settled()
    #expect(later.opened.map(\.pairedOnly) == [true])
    // Taken once: nothing is armed again for a computer whose switch is off.
    #expect(next.take() == [.disarm(F.perdixFound.id)])
    link.release()
    await first.settled()
  }

  @Test func theRowOfBreakOffsIsKeptForTheNextProcess() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [[.finished(.init(.unreachable))], FakeDiveComputerLink.script(F.perdix, [])]
    let first = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await first.settled()
    #expect(link.downloads == 1)

    // A process half a minute later refuses; one a minute after the break-off walks.
    let soon = engine(session, now: F.moment.addingTimeInterval(30))
    _ = watcher.take()
    watcher.send(.connected(F.perdixFound.id))
    await soon.settled()
    #expect(link.downloads == 1)
    #expect(watcher.take() == [.disarm(F.perdixFound.id)])
    let later = engine(session, now: F.moment.addingTimeInterval(61))
    watcher.send(.connected(F.perdixFound.id))
    await later.settled()
    #expect(link.downloads == 2)
  }

  @Test func aWalkEndAnEarlierBuildWroteWaitsTheRevisitDelay() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, [])]
    let file = root.appendingPathComponent("dive-computer-walks.json")
    let id = DiveComputerRecord(identity: F.perdix).id
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try JSONEncoder().encode([id: F.moment]).write(to: file)

    let inside = engine(session, now: F.moment.addingTimeInterval(600))
    watcher.send(.connected(F.perdixFound.id))
    await inside.settled()
    #expect(link.downloads == 0)
    let past = engine(session, now: F.moment.addingTimeInterval(1000))
    watcher.send(.connected(F.perdixFound.id))
    await past.settled()
    #expect(link.downloads == 1)
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
    await link.untilHeld()
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
    await link.untilHeld()
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
    #expect(server.atOnce.count == 2)
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

  // MARK: - While the walk runs

  /// `count` of the Perdix's dives, newest first, each read as its newest and told apart by its
  /// bytes, *perdix dive 0* first.
  private func perdixDives(_ count: Int) -> [DownloadedDive] {
    (0..<count).map { index in
      DownloadedDive(
        identity: F.perdix, fingerprint: F.fingerprint(UInt8(0x40 - index)),
        bytes: Data("perdix dive \(index)".utf8), reading: .dive(F.perdixDive))
    }
  }

  /// The dives' bytes each upload applied at once carried, as text, in the archive's order.
  private func sentDives() throws -> [[String]] {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return try server.atOnce.map { sent in
      let url = root.appendingPathComponent("sent-\(UUID().uuidString).zip")
      try #require(sent.bytes.first).write(to: url)
      let reader = try ZipReader(url)
      return try reader.entries.filter { $0.name.hasPrefix(DiveComputerArchive.filesFolder) }
        .map { String(decoding: try reader.read($0), as: UTF8.self) }
    }
  }

  /// The fake's index of dive `index` in a script of ``FakeDiveComputerLink/script(_:_:end:zone:)``.
  private func scripted(_ index: Int) -> Int { index + 2 }

  /// Lets the walk held before one event go on to the hold before `next`, or to its end.
  private func step(to next: Int?) async {
    await link.untilHeld()
    link.holdBefore = next
    link.release()
  }

  @Test func aWalkOfSlowDivesSendsEachAloneInOrderBeforeItEnds() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, perdixDives(3))]
    link.holdBefore = scripted(1)
    let clock = MovingClock(F.moment)
    let engine = engine(session, clock: clock)
    watcher.send(.connected(F.perdixFound.id))
    for sent in 1...3 {
      await until { server.atOnce.count == sent && !engine.isUploading }
      #expect(server.atOnce.count == sent)
      #expect(engine.walk != nil)
      #expect(notifier.posted.isEmpty)
      // A Suunto's dive takes minutes to read.
      clock.pass(150)
      await step(to: sent < 3 ? scripted(sent + 1) : nil)
    }
    await engine.settled()
    #expect(server.atOnce.count == 3)
    #expect(Set(server.atOnce.compactMap(\.key)).count == 3)
    #expect(try sentDives() == [["perdix dive 0"], ["perdix dive 1"], ["perdix dive 2"]])
    #expect(downloads(session).archives().isEmpty)
    #expect(downloads(session).walks().isEmpty)
    #expect(notifier.posted.map(\.title) == ["3 new dives imported"])
    #expect(notifier.posted.first?.target == .diveComputers)
  }

  @Test func aWalkOfFastDivesSendsTheFirstAloneAndTheRestNoCloserThanTheFloor() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, perdixDives(5))]
    link.holdBefore = scripted(1)
    let clock = MovingClock(F.moment)
    let began = Mutex<[TimeInterval]>([])
    server.answerAtOnce { _ in
      began.withLock { $0.append(clock.now.timeIntervalSince(F.moment)) }
      return nil
    }
    let engine = engine(session, clock: clock)
    watcher.send(.connected(F.perdixFound.id))
    await until { server.atOnce.count == 1 && !engine.isUploading }

    // A dive every ten seconds: the second and third wait for the floor's turn, which sends them
    // with no dive arriving.
    clock.pass(10)
    await step(to: scripted(2))
    await until { clock.sleeping == 1 }
    clock.pass(10)
    await step(to: scripted(3))
    await until { engine.walk?.divesDownloaded == 3 }
    #expect(server.atOnce.count == 1)
    clock.pass(10)
    await until { server.atOnce.count == 2 && !engine.isUploading }

    // The fourth and fifth arrive inside the next floor, and go at the walk's end.
    await step(to: scripted(4))
    clock.pass(10)
    await step(to: scripted(5))
    await until { engine.walk?.divesDownloaded == 5 }
    #expect(server.atOnce.count == 2)
    #expect(notifier.posted.isEmpty)
    clock.pass(5)
    await step(to: nil)
    await engine.settled()

    #expect(began.withLock { $0 } == [0, 30, 45])
    #expect(
      try sentDives() == [
        ["perdix dive 0"], ["perdix dive 1", "perdix dive 2"], ["perdix dive 3", "perdix dive 4"],
      ])
    #expect(notifier.posted.map(\.title) == ["3 new dives imported"])
  }

  @Test func theServerSeesNoTwoUploadsAtOnce() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, perdixDives(3))]
    link.holdBefore = scripted(1)
    let clock = MovingClock(F.moment)
    let gate = Mutex(true)
    let answering = Mutex((now: 0, most: 0))
    server.answerAtOnce { _ in
      answering.withLock {
        $0.now += 1
        $0.most = max($0.most, $0.now)
      }
      while gate.withLock({ $0 }) { try await Task.sleep(for: .milliseconds(2)) }
      answering.withLock { $0.now -= 1 }
      return nil
    }
    let engine = engine(session, clock: clock)
    watcher.send(.connected(F.perdixFound.id))
    await until { server.atOnce.count == 1 }

    // Past the floor, with the first unanswered: a dive and every other occasion wait for it.
    clock.pass(40)
    await step(to: scripted(2))
    await until { engine.walk?.divesDownloaded == 2 }
    engine.upload()
    engine.accountLoaded()
    clock.pass(40)
    for _ in 0..<1000 { await Task.yield() }
    #expect(server.atOnce.count == 1)

    gate.withLock { $0 = false }
    await until { !engine.isUploading }
    await step(to: nil)
    await engine.settled()
    #expect(answering.withLock { $0.most } == 1)
    #expect(try sentDives().flatMap { $0 } == ["perdix dive 0", "perdix dive 1", "perdix dive 2"])
  }

  @Test func aDiveTheTimeZoneQuestionWaitsForIsInNoneOfThem() async throws {
    let session = try await session()
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload, zone: F.helsinki)]
    // Half a day after the newer dive, a day and a half after the older.
    let engine = engine(session, now: F.moment.addingTimeInterval(30 * 60 * 60))
    watcher.send(.connected(F.oceanFound.id))
    await engine.settled()
    #expect(try sentDives() == [["ocean after"]])
    #expect(engine.held.map(\.dives) == [1])
    #expect(downloads(session).archives().isEmpty)
  }

  @Test func aBudgetSpentKeepsTheArchiveAndWhatArrivesMeanwhileIsTheOneAfterIt() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, perdixDives(4))]
    link.holdBefore = scripted(1)
    server.answerAtOnce { index in
      index == 0 ? .json(#"{"detail":"Too many imports"}"#, status: 429) : nil
    }
    let clock = MovingClock(F.moment)
    let engine = engine(session, clock: clock)
    watcher.send(.connected(F.perdixFound.id))
    await until { server.atOnce.count == 1 && !engine.isUploading }
    #expect(engine.archives.count == 1)

    clock.pass(10)
    await step(to: scripted(2))
    await until { engine.walk?.divesDownloaded == 2 }
    clock.pass(10)
    await step(to: scripted(3))
    await until { engine.walk?.divesDownloaded == 3 }
    // The floor's turn sends the refused archive again, and cuts nothing while it waits.
    clock.pass(10)
    await until { server.atOnce.count == 2 && !engine.isUploading }
    #expect(engine.archives.isEmpty)
    clock.pass(10)
    await step(to: scripted(4))
    await until { engine.walk?.divesDownloaded == 4 }
    #expect(server.atOnce.count == 2)
    await step(to: nil)
    await engine.settled()

    let keys = server.atOnce.map(\.key)
    #expect(keys.count == 3)
    #expect(keys[0] == keys[1])
    #expect(keys[2] != keys[0])
    #expect(
      try sentDives() == [
        ["perdix dive 0"], ["perdix dive 0"], ["perdix dive 1", "perdix dive 2", "perdix dive 3"],
      ])
    #expect(notifier.posted.map(\.title) == ["2 new dives imported"])
  }

  @Test func aLostAnswerIsSentAgainUnderTheKeyAndReadsTheFirstImport() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, perdixDives(2))]
    link.holdBefore = scripted(1)
    server.loseAnswers(at: [0])
    let clock = MovingClock(F.moment)
    let engine = engine(session, clock: clock)
    watcher.send(.connected(F.perdixFound.id))
    await until { server.atOnce.count == 1 && !engine.isUploading }
    #expect(engine.archives.count == 1)

    clock.pass(10)
    await step(to: nil)
    await engine.settled()
    let keys = server.atOnce.map(\.key)
    #expect(keys.count == 3)
    #expect(keys[0] == keys[1])
    #expect(try sentDives() == [["perdix dive 0"], ["perdix dive 0"], ["perdix dive 1"]])
    #expect(engine.archives.isEmpty)
    // The repeat answered the first import's rows, which count once.
    #expect(notifier.posted.map(\.title) == ["2 new dives imported"])
  }

  @Test func offlineFromMidWalkTheDiverHearsOfTheDownloadOnceEachWay() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, perdixDives(3))]
    link.holdBefore = scripted(1)
    let clock = MovingClock(F.moment)
    let engine = engine(session, clock: clock)
    watcher.send(.connected(F.perdixFound.id))
    await until { server.atOnce.count == 1 && !engine.isUploading }

    route.isRouteAvailable = false
    clock.pass(60)
    await step(to: scripted(2))
    await until { engine.walk?.divesDownloaded == 2 }
    clock.pass(60)
    await step(to: nil)
    await engine.settled()
    #expect(server.atOnce.count == 1)
    #expect(notifier.posted.map(\.title) == ["2 dives downloaded"])

    route.isRouteAvailable = true
    engine.upload()
    await engine.settled()
    #expect(try sentDives() == [["perdix dive 0"], ["perdix dive 1", "perdix dive 2"]])
    #expect(notifier.posted.map(\.title) == ["2 dives downloaded", "2 new dives imported"])
  }

  /// A new process over the same folders, launched: what it recovers, and what it then sends.
  private func nextProcess(_ session: Session) async -> DiveComputerEngine {
    let next = DiveComputerEngine(
      session: session, makeLink: { FakeDiveComputerLink() }, generator: F.generator,
      notifier: notifier, workFolder: root.appendingPathComponent("Next", isDirectory: true),
      now: { F.moment }, zone: F.helsinki)
    next.launched()
    await next.settled()
    return next
  }

  @Test func aDiveAnsweredBeforeTheProcessEndedIsNotSentAgain() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, perdixDives(3))]
    link.holdBefore = scripted(2)
    let engine = engine(session)
    var kept = 0
    engine.diveKept = { kept += 1 }
    watcher.send(.connected(F.perdixFound.id))
    // The first is answered; the second, inside the floor, is kept with the walk.
    await until { kept == 2 && server.atOnce.count == 1 && !engine.isUploading }
    #expect(downloads(session).walks().map(\.dives.count) == [1])

    // The process ends here.
    _ = await nextProcess(session)
    #expect(try sentDives() == [["perdix dive 0"], ["perdix dive 1"]])
    #expect(downloads(session).archives().isEmpty)
    #expect(downloads(session).walks().isEmpty)
    link.release()
    await engine.settled()
  }

  @Test func aProcessEndedBetweenAnArchiveAndTheWalkLeavesEachDiveInOneArchive() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    let dives = perdixDives(3)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, dives)]
    link.holdBefore = scripted(2)
    server.answerAtOnce { index in
      index == 0 ? .json(#"{"detail":"Server error"}"#, status: 503) : nil
    }
    let engine = engine(session)
    var kept = 0
    engine.diveKept = { kept += 1 }
    watcher.send(.connected(F.perdixFound.id))
    await until { kept == 2 && server.atOnce.count == 1 && !engine.isUploading }
    let first = try #require(downloads(session).archives().first)
    #expect(first.part == 0)

    // The process ended after the first archive was kept and before the walk let its dive go.
    var walk = try #require(downloads(session).walks().first)
    let again = KeptDive(dives[0], file: "again.bin")
    try again.write(dives[0], into: downloads(session).folder(of: walk.id))
    walk.dives.insert(again, at: 0)
    try downloads(session).save(walk)

    let next = await nextProcess(session)
    #expect(next.archives.isEmpty)
    #expect(downloads(session).walks().isEmpty)
    // The archive that waited goes first, under its key, and the walk's last after it.
    let keys = server.atOnce.map(\.key)
    #expect(keys.count == 3)
    #expect(keys[1] == first.key.uuidString.lowercased())
    #expect(try sentDives() == [["perdix dive 0"], ["perdix dive 0"], ["perdix dive 1"]])
    link.release()
    await engine.settled()
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
    model.pair()
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

  @Test func heldDivesThatNeverReachedTheDiskLeaveTheFingerprintWhereItWas() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    // A file where the walks' folder goes: nothing a walk keeps can be written.
    let walks = downloads(session).root.appendingPathComponent("Walks")
    try FileManager.default.createDirectory(
      at: walks.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: walks)
    let engine = engine(session)
    watcher.send(.connected(F.oceanFound.id))
    await engine.settled()

    #expect(engine.held.isEmpty)
    #expect(
      computers(session).record(family: .suuntoNautic, serial: F.ocean.serial)?.fingerprint
        == nil)
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

  /// A walk of the Perdix; `dives`, one by default, so it makes one archive with a route.
  private func walked(
    _ session: Session, route available: Bool = true,
    dives: [DownloadedDive] = [DiveComputerFixtures.perdixDownload[0]]
  ) async throws -> DiveComputerEngine {
    route.isRouteAvailable = available
    try pair(session, F.perdix, at: F.perdixFound.id)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, dives)]
    let engine = engine(session)
    watcher.send(.connected(F.perdixFound.id))
    await engine.settled()
    return engine
  }

  @Test func withNoRouteTheDivesWaitTheDiverIsToldOnceAndIOSIsLeftAWake() async throws {
    let session = try await session()
    let engine = try await walked(session, route: false, dives: F.perdixDownload)
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

  @Test func aServerThatDoesNotAnswerOverARouteLeavesNoWake() async throws {
    let session = try await session()
    server.answerAtOnce { _ in throw URLError(.cannotConnectToHost) }
    let engine = try await walked(session)
    #expect(engine.archives.count == 1)
    #expect(engine.archives.first?.refusal == nil)
    #expect(notifier.posted.isEmpty)
    #expect(wake.left.isEmpty)
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
    model.pair()
    await model.watch()
    #expect(model.phase == .scanning)

    watcher.send(.connected(F.perdixFound.id))
    await link.untilHeld()
    // The screen shows the walk where the scan was.
    #expect(model.phase == .downloading)
    link.release()
    await engine.settled()
    #expect(model.phase == .scanning)
  }

  @Test func walksQueuedOneAfterAnotherResumeTheScanOnceBothEnd() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.perdix, at: F.perdixFound.id)
    try pair(session, F.ocean, at: F.oceanFound.id)
    link.found = [F.perdixFound]
    link.scripts = [
      FakeDiveComputerLink.script(F.perdix, F.perdixDownload),
      FakeDiveComputerLink.script(F.ocean, F.oceanDownload, zone: F.helsinki),
    ]
    link.holdBeforeEnd = true
    let engine = engine(session)
    let model = DiveComputerModel(engine: engine, zone: F.helsinki)
    model.pair()
    await model.watch()
    #expect(link.scans == 1)

    watcher.send(.connected(F.perdixFound.id))
    await link.untilHeld()
    watcher.send(.connected(F.oceanFound.id))
    link.holdBeforeEnd = false
    link.release()
    await engine.settled()
    #expect(link.downloads == 2)
    #expect(link.scans == 2)
    #expect(model.phase == .scanning)
  }

  @Test func aRetryGoesUnderTheSameKeyAndTheDiverIsToldOnce() async throws {
    let session = try await session()
    // Refused while the walk ran, and again at its end.
    server.answerAtOnce { index in
      index < 2 ? .json(#"{"detail":"Server error"}"#, status: 503) : nil
    }
    let engine = try await walked(session)
    #expect(engine.archives.count == 1)
    #expect(engine.archives.first?.refusal == nil)
    #expect(notifier.posted.isEmpty)
    let archive = try #require(engine.archives.first)
    #expect(engine.lastTries == [archive.id: "Last try: the server answered 503"])

    engine.upload()
    await engine.settled()
    engine.upload()
    await engine.settled()
    let keys = server.atOnce.map(\.key)
    #expect(keys.count == 3)
    #expect(Set(keys).count == 1)
    #expect(engine.archives.isEmpty)
    #expect(engine.lastTries.isEmpty)
    #expect(!engine.isUploading)
    #expect(notifier.posted.map(\.title) == ["1 new dive imported"])
    #expect(
      watchLines().filter { $0.hasPrefix("upload ") } == [
        "upload \(archive.id): answered 503", "upload \(archive.id): answered 503",
        "upload \(archive.id): imported",
      ])
  }

  @Test(arguments: [409, 429, 500])
  func aConflictABudgetOrAServerErrorIsTriedAgainLater(status: Int) async throws {
    let session = try await session()
    server.answerAtOnce { _ in .json(#"{"detail":"Try later"}"#, status: status) }
    let engine = try await walked(session)
    // Sent while the walk ran, and again at its end.
    #expect(server.atOnce.count == 2)
    #expect(engine.archives.count == 1)
    #expect(engine.archives.first?.refusal == nil)
    engine.upload()
    await engine.settled()
    #expect(server.atOnce.count == 3)
    #expect(
      engine.lastTries.values.map { $0 } == ["Last try: the server answered \(status)"])
  }

  @Test func anUnreadableAnswerIsSaidBeneathTheDownloadThatWaits() async throws {
    let session = try await session()
    server.answerAtOnce { _ in .json(#"{"unexpected":true}"#, status: 201) }
    let engine = try await walked(session)
    let archive = try #require(engine.archives.first)
    #expect(archive.refusal == nil)
    #expect(engine.lastTries[archive.id]?.hasPrefix("Last try: ") == true)
    #expect(watchLines().last == "upload \(archive.id): unreadable response")
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
    let engine = try await walked(session, dives: F.perdixDownload)
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

  // MARK: - What the logbook holds

  /// `count` of the Perdix's dives as ``perdixDives(_:)`` makes them, each with the facts its
  /// index record gives: a wall clock a day apart, the length and the depth.
  private func listedPerdixDives(_ count: Int) -> [DownloadedDive] {
    perdixDives(count).enumerated().map { index, dive in
      DownloadedDive(
        identity: dive.identity, fingerprint: dive.fingerprint, bytes: dive.bytes,
        reading: dive.reading,
        facts: ListedDiveFacts(
          start: .wallClock(F.clock("2026-10-\(25 - index)T09:14:07")),
          length: TimeInterval(3000 + index), maxDepth: 30 + Double(index)))
    }
  }

  /// The listing a family that lists before it reads yields for `dives`, each new.
  private func listing(_ dives: [DownloadedDive]) -> DiveComputerListing {
    DiveComputerListing(
      dives: dives.count, newDives: dives.count,
      downloads: dives.map { .init(fingerprint: $0.fingerprint, facts: $0.facts ?? .init()) })
  }

  private func uuid(_ dive: DownloadedDive) -> UUID {
    DiveComputerArchive.diveUUID(dive.identity, fingerprint: dive.fingerprint)
  }

  @Test func aDiveTheLogbookHoldsIsLeftOutAndTheWalkTakesTheRestInOrder() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(3)
    server.holdInLogbook([uuid(dives[1])])
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    let engine = engine(session)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await engine.settled()

    #expect(
      server.knownQueries
        == [
          KnownDivesQuery(
            serial: "D9772626",
            dives: [
              .init(uuid: uuid(dives[0]), startedAt: "2026-10-25T09:14:07"),
              .init(uuid: uuid(dives[1]), startedAt: "2026-10-24T09:14:07"),
              .init(uuid: uuid(dives[2]), startedAt: "2026-10-23T09:14:07"),
            ])
        ])
    #expect(link.leftOut == [[dives[1].fingerprint]])
    #expect(walk.listing?.newDives == 2)
    #expect(walk.divesDownloaded == 2)
    #expect(walk.outcome?.sentence == "2 dives downloaded.")
    #expect(try sentDives().flatMap { $0 } == ["perdix dive 0", "perdix dive 2"])
    // The fingerprint moves past what was left out as past what was taken.
    #expect(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626")?.fingerprint
        == dives[0].fingerprint)
  }

  @Test func aWalkWhoseEveryDiveTheLogbookHoldsTakesNoneAndSaysNothingIsNew() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(2)
    server.holdInLogbook(Set(dives.map(uuid)))
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    let engine = engine(session)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await engine.settled()

    #expect(walk.listing?.newDives == 0)
    #expect(walk.divesDownloaded == 0)
    #expect(walk.outcome?.kind == .nothingNew)
    #expect(walk.outcome?.sentence == "No new dives since 25 October. 2 dives on this computer.")
    #expect(server.atOnce.isEmpty)
    #expect(downloads(session).walks().isEmpty)
    #expect(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626")?.fingerprint
        == dives[0].fingerprint)
  }

  /// A server without the route, one that refuses the question, and one that fails: the walk
  /// takes what it takes today.
  @Test(arguments: [nil, 403, 500] as [Int?])
  func withNoAnswerFromTheServerTheWalkTakesWhatItTakesToday(status: Int?) async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(3)
    if let status {
      server.holdInLogbook(Set(dives.map(uuid)))
      server.answerKnownDives { _ in .json(#"{"detail":"No"}"#, status: status) }
    }
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    let engine = engine(session)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await engine.settled()
    #expect(server.knownQueries.count == 1)
    #expect(link.leftOut == [[]])
    #expect(walk.divesDownloaded == 3)
  }

  @Test func withNoRouteTheServerIsNotAskedAndTheWalkTakesEveryDive() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(3)
    server.holdInLogbook(Set(dives.map(uuid)))
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    let engine = engine(session)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await engine.settled()
    #expect(server.knownQueries.isEmpty)
    #expect(walk.divesDownloaded == 3)
  }

  /// A walk kept for the last account before this process loaded one may be another account's.
  @Test func beforeTheAccountLoadsTheServerIsNotAsked() async throws {
    let earlier = try await session()
    let fresh = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: route, applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    _ = earlier
    try pair(fresh, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(2)
    server.holdInLogbook(Set(dives.map(uuid)))
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    let engine = engine(fresh)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await engine.settled()
    #expect(server.knownQueries.isEmpty)
    #expect(walk.divesDownloaded == 2)
  }

  @Test func aServerThatDoesNotAnswerWithinTenSecondsIsNotWaitedFor() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(2)
    server.holdInLogbook(Set(dives.map(uuid)))
    server.answerKnownDives { _ in
      try await Task.sleep(for: .seconds(60 * 60))
      return nil
    }
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    let clock = MovingClock(F.moment)
    let engine = engine(session, clock: clock)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await until { server.knownQueries.count == 1 && clock.sleeping > 0 }
    clock.pass(9)
    for _ in 0..<100 { await Task.yield() }
    #expect(link.leftOut.isEmpty)
    #expect(walk.divesDownloaded == 0)
    clock.pass(1)
    await until { !link.leftOut.isEmpty }
    #expect(link.leftOut == [[]])
    await until { walk.divesDownloaded == 2 }
    #expect(walk.divesDownloaded == 2)
    await engine.settled()
  }

  /// No dive is read while the engine waits for the server: the link holds until it answers.
  @Test func noDiveIsReadBeforeTheServerHasAnswered() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(2)
    server.holdInLogbook([uuid(dives[0])])
    let (gate, open) = AsyncStream<Void>.makeStream()
    server.answerKnownDives { _ in
      for await _ in gate { break }
      return nil
    }
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    let engine = engine(session)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await until { server.knownQueries.count == 1 }
    for _ in 0..<100 { await Task.yield() }
    #expect(walk.divesDownloaded == 0)
    #expect(walk.listing == nil)
    #expect(downloads(session).walks().isEmpty)
    open.yield()
    await engine.settled()
    #expect(link.leftOut == [[dives[0].fingerprint]])
    #expect(walk.divesDownloaded == 1)
  }

  /// A Nautic's start is an instant: in the offset its summary logged, else in UTC.
  @Test func anOceansDivesAreAskedForByTheirInstant() async throws {
    let session = try await session()
    try pair(session, F.ocean, at: F.oceanFound.id)
    let logged = Date(timeIntervalSince1970: 1_793_016_109)
    let unlogged = Date(timeIntervalSince1970: 1_792_836_000)
    let dives = zip(F.oceanDownload, [(logged, 10800), (unlogged, nil)] as [(Date, Int?)]).map {
      dive, start in
      DownloadedDive(
        identity: dive.identity, fingerprint: dive.fingerprint, bytes: dive.bytes,
        reading: dive.reading,
        facts: ListedDiveFacts(start: .instant(start.0, offsetSeconds: start.1)))
    }
    server.holdInLogbook([])
    link.scripts = [FakeDiveComputerLink.script(F.ocean, listing: listing(dives), dives)]
    let engine = engine(session)
    let walk = try #require(engine.start(F.oceanFound, all: false))
    // The dives logged no zone, and the watch reported none.
    await until { walk.phase == .askingTimeZone }
    engine.cancel(walk)
    await engine.settled()
    #expect(
      server.knownQueries.first?.dives
        == [
          .init(uuid: uuid(dives[0]), startedAt: "2026-10-26T15:01:49+03:00"),
          .init(uuid: uuid(dives[1]), startedAt: "2026-10-24T10:00:00+00:00"),
        ])
    #expect(server.knownQueries.first?.serial == "253810000400")
  }

  @Test func aListPastTheBoundIsAskedInParts() async throws {
    let session = try await session()
    try pair(session, F.perdix, at: F.perdixFound.id)
    let downloads = (0..<2001).map { index in
      DiveComputerListing.Download(
        fingerprint: Data([UInt8(index >> 8), UInt8(index & 0xFF), 0, 1]),
        facts: ListedDiveFacts(start: .wallClock(F.clock("2026-10-25T09:14:07"))))
    }
    let held = downloads[2000]
    server.holdInLogbook([DiveComputerArchive.diveUUID(F.perdix, fingerprint: held.fingerprint)])
    link.scripts = [
      FakeDiveComputerLink.script(
        F.perdix, listing: DiveComputerListing(dives: 2001, newDives: 2001, downloads: downloads),
        [])
    ]
    let engine = engine(session)
    engine.start(F.perdixFound, all: false)
    await engine.settled()
    #expect(server.knownQueries.map(\.dives.count) == [2000, 1])
    #expect(link.leftOut == [[held.fingerprint]])
  }

  /// From the list until the server answers, a dive's facts are where the dive is: with the
  /// walk's queue, the dive the walk keeps, and its archive.
  @Test func theFactsStayWithADiveUntilItsImportIsAnswered() async throws {
    let session = try await session()
    route.isRouteAvailable = false
    try pair(session, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(3)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    link.holdBefore = 3
    let engine = engine(session)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await link.untilHeld()
    await until { walk.divesDownloaded == 1 }
    #expect(walk.queue.map(\.fingerprint) == dives.dropFirst().map(\.fingerprint))
    #expect(walk.inTransfer?.facts == dives[1].facts)
    #expect(walk.diveUUID(try #require(walk.queue.first)) == uuid(dives[1]))
    #expect(
      engine.divesOnPhone.map(\.id) == [uuid(dives[0])]
        && engine.divesOnPhone.first?.facts == dives[0].facts
        && engine.divesOnPhone.first?.wait == .route)
    let kept = try #require(downloads(session).walks().first)
    #expect(kept.dives.map(\.facts) == [dives[0].facts])
    link.release()
    await engine.settled()

    #expect(walk.queue.isEmpty)
    let archive = try #require(downloads(session).archives().first)
    #expect(archive.facts == Dictionary(uniqueKeysWithValues: dives.map { (uuid($0), $0.facts!) }))
    #expect(engine.divesOnPhone.map(\.id) == dives.map(uuid))
    #expect(engine.divesOnPhone.map(\.archive) == Array(repeating: archive.id, count: 3))
    #expect(engine.divesOnPhone.map(\.wait) == Array(repeating: .route, count: 3))

    route.isRouteAvailable = true
    engine.upload()
    await engine.settled()
    #expect(engine.divesOnPhone.isEmpty)
  }

  @Test func whatTheDivesOnThePhoneWaitForFollowsTheirArchive() async throws {
    let session = try await session()
    let engine = try await walked(session, route: false, dives: listedPerdixDives(1))
    #expect(engine.divesOnPhone.map(\.wait) == [.route])
    let archive = try #require(engine.archives.first)
    var refused = archive
    refused.refusal = .server(message: nil)
    try downloads(session).save(refused)
    engine.reload()
    #expect(engine.divesOnPhone.map(\.wait) == [.refused])
    var record = try #require(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626"))
    record.awaitsOrder = true
    try computers(session).save(record)
    try downloads(session).save(archive)
    engine.reload()
    #expect(engine.divesOnPhone.map(\.wait) == [.order])
  }

  @Test func anArchiveTheServerDidNotTakeOnItsLastTryWaitsToBeTriedAgain() async throws {
    let session = try await session()
    server.answerAtOnce { _ in .json(#"{"detail":"Try later"}"#, status: 503) }
    let engine = try await walked(session, dives: listedPerdixDives(1))
    #expect(engine.divesOnPhone.map(\.wait) == [.retry])
  }

  /// A walk kept for the last account before this process loaded one keeps its dives until it
  /// ends, which asks nothing of the diver; with no route they wait for the route.
  @Test func aWalkBegunBeforeTheAccountLoadedKeepsItsDivesUntilItEnds() async throws {
    _ = try await session()
    let fresh = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: route, applicationSupport: root,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    try pair(fresh, F.perdix, at: F.perdixFound.id)
    let dives = listedPerdixDives(2)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, listing: listing(dives), dives)]
    link.holdBefore = 3
    let engine = engine(fresh)
    let walk = try #require(engine.start(F.perdixFound, all: false))
    await link.untilHeld()
    await until { walk.divesDownloaded == 1 }
    #expect(engine.divesOnPhone.map(\.wait) == [.walkEnd])
    route.isRouteAvailable = false
    engine.upload()
    #expect(engine.divesOnPhone.map(\.wait) == [.route])
    link.release()
    await engine.settled()
  }
}

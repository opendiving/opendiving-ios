import Foundation
import Testing

@testable import OpenDivingKit

/// The download that outlives its screen, the button's content and the icon's bars.
@MainActor
struct DiveComputerDownloadsTests {
  private typealias F = DiveComputerFixtures

  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("DiveComputerDownloadsTests-\(UUID().uuidString)", isDirectory: true)

  private func downloads(_ link: FakeDiveComputerLink) async throws -> (
    DiveComputerDownloads, DiveComputerEngine
  ) {
    let route = SwitchedRoute()
    route.isRouteAvailable = false
    let session = Session(
      transport: try ImportServer(),
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), connectivity: route,
      applicationSupport: root, userAgent: ClientHarness.userAgent, accessToken: "live")
    try await session.loadAccount()
    let engine = DiveComputerEngine(
      session: session, makeLink: { link }, generator: F.generator,
      workFolder: root.appendingPathComponent("Work", isDirectory: true), now: { F.moment },
      zone: F.helsinki)
    let downloads = DiveComputerDownloads(engine: engine, zone: F.helsinki)
    return (downloads, engine)
  }

  /// Starts a download the link holds before its end, until ``FakeDiveComputerLink/release()``,
  /// and waits until the model has taken in every dive before the hold.
  private func start(_ model: DiveComputerModel, _ link: FakeDiveComputerLink) async throws {
    model.pair()
    await model.watch()
    await until { !model.rows.isEmpty }
    model.connect(try #require(model.rows.first))
    let atTheHold = { link.isHeld && model.divesDownloaded == F.perdixDownload.count }
    await until(atTheHold)
    try #require(atTheHold())
  }

  /// Waits for what the model reads on its own task, however busy the main actor is with other
  /// suites.
  private func until(_ condition: () -> Bool) async {
    for _ in 0..<100_000 where !condition() { await Task.yield() }
  }

  @Test func leavingIdleClosesTheModelAndTheNextVisitIsFresh() async throws {
    let link = FakeDiveComputerLink()
    let (downloads, _) = try await downloads(link)
    let first = downloads.model
    downloads.screenAppeared()
    downloads.screenDisappeared()

    #expect(downloads.button == nil)
    #expect(downloads.model !== first)
  }

  @Test func aComputersPageOverTheScreenKeepsTheOutcomeUntilTheScreenIsLeft() async throws {
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [
      FakeDiveComputerLink.script(
        F.perdix, listing: .init(dives: 3, newDives: 0), [])
    ]
    let (downloads, _) = try await downloads(link)
    let model = downloads.model
    downloads.screenAppeared()
    model.pair()
    await model.watch()
    await until { !model.rows.isEmpty }
    model.connect(try #require(model.rows.first))
    await model.settled()
    let outcome = try #require(model.outcome)

    downloads.screenAppeared()
    downloads.screenDisappeared()
    downloads.screenAppeared()
    downloads.screenDisappeared()
    #expect(downloads.model === model)
    #expect(model.outcome == outcome)

    downloads.screenDisappeared()
    #expect(downloads.model !== model)
  }

  /// Leaving the screen from a computer's page closes the model under it: *Forget* reaches
  /// whichever model is current, and the next visit lists what is left.
  @Test func forgettingFromAPageThatCoveredTheScreenHoldsOnTheNextVisit() async throws {
    let link = FakeDiveComputerLink()
    let (downloads, _) = try await downloads(link)
    let store = DiveComputerStore(
      store: ServerStateStore(
        root: root, secrets: InMemorySecretStore(),
        activeOrigin: InMemoryActiveOriginStore(ImportServer.origin)),
      origin: ImportServer.origin, account: ImportServer.accountA)
    let record = DiveComputerRecord(identity: F.perdix)
    try store.save(record)
    downloads.screenAppeared()
    await downloads.model.watch()
    #expect(downloads.model.paired.map(\.id) == [record.id])

    downloads.screenDisappeared()
    downloads.model.forget(record)
    downloads.screenAppeared()
    await downloads.model.watch()

    #expect(downloads.model.paired.isEmpty)
    #expect(store.records().isEmpty)
  }

  @Test func leavingMidDownloadKeepsItAndTheButtonShowsUntilTheScreenIsSeen() async throws {
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let (downloads, engine) = try await downloads(link)
    let model = downloads.model
    #expect(downloads.screenAppeared() == nil)
    try await start(model, link)

    downloads.screenDisappeared()
    #expect(!link.cancelled)
    #expect(downloads.model === model)
    #expect(downloads.button?.state == .working)
    #expect(downloads.button?.ring == .fraction(0.25))

    link.release()
    await model.settled()
    #expect(engine.archives.count == 1)
    // The end came while away: the button stays, finished, until the screen shows it.
    #expect(downloads.button?.state == .succeeded)
    #expect(downloads.button?.ring == .fraction(1))
    #expect(downloads.screenAppeared()?.kind == .kept)
    #expect(downloads.button == nil)
    #expect(downloads.model === model)

    downloads.screenDisappeared()
    #expect(downloads.button == nil)
    #expect(downloads.model !== model)
  }

  @Test func aSecondScreenKeepsTheButtonHidden() async throws {
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let (downloads, _) = try await downloads(link)
    let model = downloads.model
    downloads.screenAppeared()
    try await start(model, link)
    downloads.screenDisappeared()
    downloads.screenAppeared()
    downloads.screenAppeared()
    downloads.screenDisappeared()

    #expect(downloads.button == nil)
    #expect(downloads.model === model)
    link.release()
    await model.settled()
  }

  @Test func theSessionChangingCancelsWhatIsInFlight() async throws {
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let (downloads, _) = try await downloads(link)
    let model = downloads.model
    downloads.screenAppeared()
    try await start(model, link)
    downloads.screenDisappeared()

    downloads.sessionChanged()
    #expect(link.cancelled)
    #expect(downloads.button == nil)
    #expect(downloads.model !== model)
    link.release()
    await model.settled()
  }

  /// Pairs the Perdix on the phone, as the watch knows it, and has it connect to the watch's
  /// request: a walk nobody started, held before its end with every dive before the hold in.
  private func connect(
    _ engine: DiveComputerEngine, _ link: FakeDiveComputerLink
  ) async throws -> DiveComputerRecord {
    var record = DiveComputerRecord(identity: F.perdix, peripheral: F.perdixFound.id)
    record.answeredQuestion = true
    try computers().save(record)
    #expect(engine.connected(F.perdixFound.id, record: record))
    let atTheHold = { link.isHeld && engine.walk?.divesDownloaded == F.perdixDownload.count }
    await until(atTheHold)
    try #require(atTheHold())
    return record
  }

  private func computers() -> DiveComputerStore {
    DiveComputerStore(
      store: ServerStateStore(
        root: root, secrets: InMemorySecretStore(),
        activeOrigin: InMemoryActiveOriginStore(ImportServer.origin)),
      origin: ImportServer.origin, account: ImportServer.accountA)
  }

  @Test func aDownloadNobodyStartedQueuedBehindTheDiversWaitsForItsOutcomeToGo() async throws {
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [
      FakeDiveComputerLink.script(F.perdix, F.perdixDownload),
      FakeDiveComputerLink.script(F.ocean, F.oceanDownload, zone: F.helsinki),
    ]
    link.holdBeforeEnd = true
    let (downloads, engine) = try await downloads(link)
    var ocean = DiveComputerRecord(identity: F.ocean, peripheral: F.oceanFound.id)
    ocean.answeredQuestion = true
    try computers().save(ocean)
    let model = downloads.model
    downloads.screenAppeared()
    try await start(model, link)
    #expect(engine.connected(F.oceanFound.id, record: ocean))

    link.release()
    await until { engine.walk?.computer.id == F.oceanFound.id && link.isHeld }
    #expect(engine.walk?.computer.id == F.oceanFound.id)
    #expect(model.outcome?.kind == .kept)
    #expect(model.pageWalk(ocean) == .none)

    // Where a scan would clear the outcome, the walk it held back is shown instead, and the
    // scan waits for its end.
    let scans = link.scans
    model.pair()
    #expect(model.pageWalk(ocean) == .running)
    #expect(link.scans == scans)

    link.release()
    await engine.settled()
    #expect(model.phase == .scanning)
    #expect(link.scans == scans + 1)
  }

  @Test func aDownloadNobodyStartedDrawsTheButtonWhileItRuns() async throws {
    let link = FakeDiveComputerLink()
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let (downloads, engine) = try await downloads(link)
    _ = try await connect(engine, link)

    #expect(downloads.button?.state == .working)
    #expect(downloads.button?.ring == .fraction(0.25))

    link.release()
    await engine.settled()
    #expect(engine.archives.count == 1)
    // Its outcome is the notification's.
    #expect(downloads.button == nil)
  }

  @Test func theScreenShowsADownloadNobodyStartedAsTheDiversAndATapStillTakesOver() async throws {
    let link = FakeDiveComputerLink()
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let (downloads, engine) = try await downloads(link)
    let record = try await connect(engine, link)

    // Opened mid-walk, the screen takes it in, and the button gives way to it.
    downloads.screenAppeared()
    let model = downloads.model
    await model.watch()
    #expect(downloads.button == nil)
    #expect(model.phase == .downloading)
    #expect(model.pageWalk(record) == .running)
    #expect(model.progress == 0.25)
    #expect(model.downloadingText == engine.walk?.downloadingText)
    #expect(model.canDownload(record))

    // Left while it runs, the button draws it through its end, as the diver's.
    downloads.screenDisappeared()
    #expect(downloads.model === model)
    #expect(downloads.button?.state == .working)
    link.release()
    await engine.settled()
    #expect(downloads.button?.state == .succeeded)
    #expect(downloads.screenAppeared()?.kind == .kept)
    #expect(model.pageWalk(record) == .finished(try #require(model.outcome)))
  }

  @Test func leftDuringADownloadNobodyStartedTheScanItStoppedStaysStopped() async throws {
    let link = FakeDiveComputerLink()
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let (downloads, engine) = try await downloads(link)
    downloads.screenAppeared()
    let model = downloads.model
    model.pair()
    await model.watch()
    #expect(model.phase == .scanning)
    _ = try await connect(engine, link)
    let scans = link.scans

    downloads.screenDisappeared()
    link.release()
    await engine.settled()
    #expect(link.scans == scans)
    #expect(downloads.button?.state == .succeeded)
    #expect(downloads.screenAppeared()?.kind == .kept)
  }

  @Test func aDownloadNobodyStartedIsShownFromItsStart() async throws {
    let link = FakeDiveComputerLink()
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBeforeEnd = true
    let (downloads, engine) = try await downloads(link)
    downloads.screenAppeared()
    let model = downloads.model
    let record = try await connect(engine, link)

    #expect(model.pageWalk(record) == .running)
    model.cancel()
    await engine.settled()
    #expect(link.cancelled)
    // What it downloaded before the cancel is kept, as the diver's would be.
    #expect(model.outcome?.kind == .kept)
  }

  @Test func theBarsRiseInTurnThenFadeTogether() {
    func lengths(_ t: TimeInterval) -> [Double] { DiveComputerBars.frame(at: t).map(\.length) }
    #expect(lengths(0) == [0, 0, 0])
    #expect(DiveComputerBars.frame(at: 0).allSatisfy { $0.opacity == 0 })
    #expect(lengths(0.3) == [1, 0, 0])
    #expect(lengths(0.65) == [1, 1, 0])
    #expect(lengths(1.0) == [1, 1, 1])
    #expect(DiveComputerBars.frame(at: 1.2).allSatisfy { $0.opacity == 1 })
    // No empty icon between loops: the bars are still fading as the loop ends.
    #expect(DiveComputerBars.frame(at: DiveComputerBars.loop - 0.01).allSatisfy { $0.opacity > 0 })
    #expect(
      DiveComputerBars.frame(at: DiveComputerBars.loop + 0.3) == DiveComputerBars.frame(at: 0.3))
  }
}

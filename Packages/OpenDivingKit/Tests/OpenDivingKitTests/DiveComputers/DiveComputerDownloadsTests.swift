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
    DiveComputerDownloads, InboxModel
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
    let inbox = InboxModel(session: session)
    inbox.sessionChanged()
    let root = root
    let downloads = DiveComputerDownloads {
      DiveComputerModel(
        session: session, inbox: inbox, link: link, generator: F.generator,
        workFolder: root.appendingPathComponent("Work", isDirectory: true), now: { F.moment },
        zone: F.helsinki)
    }
    return (downloads, inbox)
  }

  /// Starts a download the link holds before its end, until ``FakeDiveComputerLink/release()``,
  /// and waits until the model has taken in every dive before the hold.
  private func start(_ model: DiveComputerModel, _ link: FakeDiveComputerLink) async throws {
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

  /// Leaving by another tab from a computer's page closes the model under it: *Forget* reaches
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
    let (downloads, inbox) = try await downloads(link)
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
    #expect(inbox.files.count == 1)
    // The end came while away: the button stays, finished, until the screen shows it.
    #expect(downloads.button?.state == .succeeded)
    #expect(downloads.button?.ring == .fraction(1))
    #expect(downloads.screenAppeared()?.kind == .handedOver)
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

  @Test func theBarsRiseInTurnThenFadeTogether() {
    func lengths(_ t: TimeInterval) -> [Double] { DiveComputerBars.frame(at: t).map(\.length) }
    #expect(lengths(0) == [0, 0, 0])
    #expect(DiveComputerBars.frame(at: 0).allSatisfy { $0.opacity == 0 })
    #expect(lengths(0.3) == [1, 0, 0])
    #expect(lengths(0.65) == [1, 1, 0])
    #expect(lengths(1.0) == [1, 1, 1])
    #expect(DiveComputerBars.frame(at: 1.2).allSatisfy { $0.opacity == 1 })
    #expect(DiveComputerBars.frame(at: DiveComputerBars.loop - 0.01).allSatisfy { $0.opacity == 0 })
    #expect(
      DiveComputerBars.frame(at: DiveComputerBars.loop + 0.3) == DiveComputerBars.frame(at: 0.3))
  }
}

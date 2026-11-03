import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The download model over a fake link that replays scripted downloads into a temporary
/// account directory, with the inbox and the server stubbed: what lands in the inbox, what the
/// account remembers, and what each state says.
@MainActor
struct DiveComputerModelTests {
  private typealias F = DiveComputerFixtures

  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("DiveComputerModelTests-\(UUID().uuidString)", isDirectory: true)
  private let log = EventLog()

  /// A session signed in, with the account loaded unless `loaded` is false. No route, so the
  /// inbox reads nothing on its own.
  private func session(_ server: ImportServer, loaded: Bool = true) async throws -> Session {
    let route = SwitchedRoute()
    route.isRouteAvailable = false
    let session = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: LoggingBackgroundExecution(log: log), connectivity: route,
      applicationSupport: root, userAgent: ClientHarness.userAgent, accessToken: "live")
    if loaded { try await session.loadAccount() }
    return session
  }

  private func model(
    _ session: Session, _ inbox: InboxModel, _ link: FakeDiveComputerLink
  ) -> DiveComputerModel {
    inbox.sessionChanged()
    return DiveComputerModel(
      session: session, inbox: inbox, link: link, generator: F.generator,
      workFolder: root.appendingPathComponent("Work", isDirectory: true), now: { F.moment },
      zone: F.helsinki)
  }

  private func scanned(_ model: DiveComputerModel) async throws -> DiveComputerModel.Row {
    await model.watch()
    for _ in 0..<1000 where model.rows.isEmpty { await Task.yield() }
    return try #require(model.rows.first)
  }

  private func download(_ model: DiveComputerModel) async throws {
    model.connect(try await scanned(model))
    await model.settled()
  }

  private func computers(_ session: Session, _ account: UUID = ImportServer.accountA)
    -> DiveComputerStore
  {
    DiveComputerStore(store: session.store, origin: ImportServer.origin, account: account)
  }

  @Test func aCompletedDownloadIsOneArchiveInTheInboxAndAdvancesTheRecord() async throws {
    let session = try await session(try ImportServer())
    let inbox = InboxModel(session: session)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    let model = model(session, inbox, link)

    let row = try await scanned(model)
    #expect(row.title == "Shearwater Perdix 3")
    #expect(row.subtitle == nil)
    #expect(model.paired.isEmpty)
    #expect(model.unpairedRows == [row])
    model.connect(row)
    await model.settled()

    #expect(model.phase == .finished)
    #expect(model.outcome?.kind == .handedOver)
    #expect(model.outcome?.sentence == "2 dives downloaded. 1 dive could not be read.")
    let file = try #require(inbox.files.first)
    #expect(inbox.files.count == 1)
    #expect(file.filename == "shearwater-perdix-3_D9772626_2026-10-25T0920.zip")
    #expect(
      DiveComputerText.inboxRow(try #require(file.download), in: F.helsinki)
        == "2 dives from Shearwater Perdix 3, downloaded 25 October")
    #expect(inbox.removalNeedsConfirmation(file))
    #expect(inbox.removeAllNeedsConfirmation)

    let record = try #require(
      computers(session).record(family: .shearwaterPetrel, serial: "d9772626"))
    #expect(record.fingerprint == F.fingerprint(3))
    #expect(record.lastDownloaded == F.moment)
    #expect(record.peripheral == F.perdixFound.id)
    #expect(!record.receivedBeforeAccountKnown)
    #expect(log.all == ["begin", "end"])
    #expect(link.fingerprintsSet == [nil])

    // The row now carries what the phone remembers.
    model.startScanning()
    for _ in 0..<1000 where model.rows.first?.subtitle == nil { await Task.yield() }
    #expect(model.rows.first?.subtitle == "Serial D9772626 · Last downloaded 25 October")
    // It is paired now: listed among the paired computers, connectable while seen, and no
    // longer among the others found.
    let paired = try #require(model.paired.first)
    #expect(model.paired.count == 1)
    #expect(paired.title == "Shearwater Perdix 3")
    #expect(paired.subtitle == "Serial D9772626 · Last downloaded 25 October")
    #expect(paired.row?.computer == F.perdixFound)
    #expect(model.unpairedRows.isEmpty)
  }

  @Test func nothingNewOffersDownloadAllWhichSetsNoFingerprint() async throws {
    let session = try await session(try ImportServer())
    let inbox = InboxModel(session: session)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [
      FakeDiveComputerLink.script(F.perdix, F.perdixDownload),
      FakeDiveComputerLink.script(F.perdix, []),
      FakeDiveComputerLink.script(F.perdix, Array(F.perdixDownload.prefix(1))),
    ]
    let model = model(session, inbox, link)
    try await download(model)
    try await download(model)

    #expect(link.fingerprintsSet == [nil, F.fingerprint(3)])
    #expect(model.outcome?.kind == .nothingNew)
    #expect(model.outcome?.sentence == "No new dives since 25 October.")
    #expect(model.outcome?.offersDownloadAll == true)

    model.downloadAll()
    await model.settled()
    #expect(link.fingerprintsSet == [nil, F.fingerprint(3), nil])
    #expect(model.outcome?.kind == .handedOver)
    // Two download archives of one mark are one union, never two files.
    #expect(inbox.files.count == 1)
    #expect(inbox.files.first?.download?.dives == 2)
  }

  @Test func aComputerThatListsNoDiveSaysSo() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, [])]
    let model = model(session, InboxModel(session: session), link)
    try await download(model)
    #expect(model.outcome?.kind == .noDives)
    #expect(model.outcome?.sentence == "No dives on this computer.")
  }

  @Test func anEmptyReadOrACancelHandsTheDivesOverAndLeavesTheFingerprint() async throws {
    let session = try await session(try ImportServer())
    let inbox = InboxModel(session: session)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [
      FakeDiveComputerLink.script(F.perdix, F.perdixDownload, end: .init(.complete, emptyReads: 1))
    ]
    let model = model(session, inbox, link)
    try await download(model)
    #expect(model.outcome?.kind == .handedOver)
    #expect(inbox.files.count == 1)
    let record = try #require(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626"))
    #expect(record.fingerprint == nil)
    #expect(record.lastDownloaded == nil)

    link.holdBeforeEnd = true
    link.scripts = [FakeDiveComputerLink.script(F.perdix, Array(F.perdixDownload.prefix(2)))]
    model.connect(try #require(model.rows.first))
    for _ in 0..<1000 where !link.isHeld || model.divesDownloaded < 2 { await Task.yield() }
    #expect(model.phase == .downloading)
    #expect(model.downloadingText == "Downloading dive 3")
    #expect(model.progress == 0.25)
    model.cancel()
    link.release()
    await model.settled()
    #expect(model.outcome?.sentence == "The download was cancelled. 2 dives downloaded.")
    #expect(
      computers(session).record(family: .shearwaterPetrel, serial: "D9772626")?.fingerprint == nil)
  }

  /// A watch's run is no dive, but the walk met it: the fingerprint moves past it as past a dive,
  /// or every later download would meet it again.
  @Test func anEntrySkippedAsNoDiveAdvancesTheFingerprintPastIt() async throws {
    let session = try await session(try ImportServer())
    let inbox = InboxModel(session: session)
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    link.scripts = [
      [.identified(F.ocean), .watchZone(F.helsinki), .skipped(fingerprint: F.fingerprint(0x13))]
        + F.oceanDownload.map { .dive($0) } + [.finished(.init(.complete))],
      [
        .identified(F.ocean), .skipped(fingerprint: F.fingerprint(0x14)),
        .finished(.init(.complete)),
      ],
      [.identified(F.ocean), .finished(.init(.complete))],
    ]
    let model = model(session, inbox, link)
    try await download(model)
    #expect(model.outcome?.sentence == "2 dives downloaded.")
    #expect(inbox.files.first?.download?.dives == 2)
    let ocean = { computers(session).record(family: .suuntoNautic, serial: "253810000400") }
    #expect(ocean()?.fingerprint == F.fingerprint(0x13))

    // A walk that met only skipped entries keeps no archive and still advances.
    try await download(model)
    #expect(model.outcome?.kind == .nothingNew)
    #expect(model.outcome?.sentence == "No new dives since 25 October.")
    #expect(inbox.files.count == 1)
    #expect(ocean()?.fingerprint == F.fingerprint(0x14))
    #expect(ocean()?.lastDownloaded == F.moment)

    try await download(model)
    #expect(link.fingerprintsSet == [nil, F.fingerprint(0x13), F.fingerprint(0x14)])
  }

  @Test func aSkipOnlyWalkThatMetAnEmptyReadLeavesTheFingerprint() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    link.scripts = [
      [
        .identified(F.ocean), .skipped(fingerprint: F.fingerprint(0x14)),
        .finished(.init(.complete, emptyReads: 1)),
      ]
    ]
    let model = model(session, InboxModel(session: session), link)
    try await download(model)
    #expect(model.outcome?.kind == .noDives)
    #expect(computers(session).record(family: .suuntoNautic, serial: "253810000400") == nil)
  }

  @Test func aNauticWalkThatFailsBeforeAnyDiveNamesTheSuuntoApp() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    link.scripts = [
      [.identified(F.ocean), .finished(.init(.failed(status: "DC_STATUS_PROTOCOL")))]
    ]
    let model = model(session, InboxModel(session: session), link)
    let row = try await scanned(model)
    #expect(row.title == "Suunto Ocean")
    #expect(row.subtitle == "Serial 253810000400")
    model.connect(row)
    await model.settled()
    #expect(model.outcome?.kind == .failed)
    #expect(
      model.outcome?.sentence
        == "The Suunto app is still connected to this computer. Unpair it there, then connect"
        + " again. The download stopped: DC_STATUS_PROTOCOL.")
  }

  @Test func aComputerThatDoesNotAnswerSaysToWakeIt() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [[.finished(.init(.unreachable))]]
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await model.settled()
    #expect(model.outcome?.kind == .failed)
    #expect(
      model.outcome?.sentence
        == "The dive computer did not answer. Wake it and turn on its Bluetooth, then connect"
        + " again.")
  }

  @Test func instantsWithNoZoneAskAfterTheWalkOutsideTheBackgroundAssertion() async throws {
    let session = try await session(try ImportServer())
    let inbox = InboxModel(session: session)
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload)]
    let model = model(session, inbox, link)
    model.connect(try await scanned(model))
    for _ in 0..<1000 where model.phase != .askingTimeZone { await Task.yield() }
    #expect(model.phase == .askingTimeZone)
    #expect(inbox.files.isEmpty)
    #expect(log.all == ["begin", "end"])

    let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
    model.answerTimeZone(tokyo)
    await model.settled()
    #expect(log.all == ["begin", "end", "begin", "end"])
    let record = try #require(
      computers(session).record(family: .suuntoNautic, serial: "253810000400"))
    #expect(record.diverZone == tokyo)
    #expect(record.watchZone == nil)
    let file = try #require(inbox.files.first)
    let started = try startedAt(inbox, file)
    #expect(started == ["2026-10-26T19:00:00+09:00", "2026-10-24T19:00:00+09:00"])
  }

  @Test func theWatchsZoneIsUsedAndKeptWithNoQuestion() async throws {
    let session = try await session(try ImportServer())
    let inbox = InboxModel(session: session)
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    link.scripts = [FakeDiveComputerLink.script(F.ocean, F.oceanDownload, zone: F.helsinki)]
    let model = model(session, inbox, link)
    try await download(model)
    #expect(log.all == ["begin", "end"])
    let record = try #require(
      computers(session).record(family: .suuntoNautic, serial: "253810000400"))
    #expect(record.watchZone == F.helsinki)
    #expect(record.diverZone == nil)
    #expect(
      try startedAt(inbox, try #require(inbox.files.first)) == [
        "2026-10-26T12:00:00+02:00", "2026-10-24T13:00:00+03:00",
      ])
  }

  @Test func aSharedArchiveWaitingOrAnAccountLoadingStartsNothing() async throws {
    let server = try ImportServer()
    let session = try await session(server)
    let inbox = InboxModel(session: session)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    let model = model(session, inbox, link)

    let export = root.appendingPathComponent("opendiving-export.zip")
    var zip = try ZipWriter(creating: export, moment: F.moment, zone: F.helsinki)
    try zip.add("logbook.divejson", Data("{}".utf8))
    try zip.finish()
    inbox.receive([export], moving: true)
    await model.watch()
    #expect(model.phase == .idle)
    #expect(model.blocker == DiveComputerText.archiveWaiting)

    let other = FileManager.default.temporaryDirectory
      .appendingPathComponent("DiveComputerModelTests-\(UUID().uuidString)", isDirectory: true)
    let fresh = Session(
      transport: server,
      secrets: InMemorySecretStore([ImportServer.origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(ImportServer.origin),
      background: NoBackgroundExecution(), applicationSupport: other,
      userAgent: ClientHarness.userAgent, accessToken: "live")
    let loading = DiveComputerModel(
      session: fresh, inbox: InboxModel(session: fresh), link: link, generator: F.generator)
    await loading.watch()
    #expect(loading.blocker == DiveComputerText.accountLoading)
    #expect(link.downloads == 0)
  }

  @Test func aDownloadBeforeTheLoadIsMarkedAndALoadNamingAnotherAccountRemovesItsRecord()
    async throws
  {
    let server = try ImportServer()
    let first = try await session(server)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    try await download(model(first, InboxModel(session: first), link))

    // Signed in again, the account not yet loaded: A's inbox, marked, beside A's own archive.
    let later = try await session(server, loaded: false)
    let inbox = InboxModel(session: later)
    link.scripts = [FakeDiveComputerLink.script(F.perdix, Array(F.perdixDownload.prefix(1)))]
    try await download(model(later, inbox, link))
    #expect(inbox.files.count == 2)
    #expect(inbox.files.map(\.receivedBeforeAccountKnown) == [false, true])
    #expect(
      computers(later).record(family: .shearwaterPetrel, serial: "D9772626")?
        .receivedBeforeAccountKnown == true)

    server.signIn(as: ImportServer.accountB)
    try await later.loadAccount()
    inbox.sessionChanged()
    #expect(computers(later).record(family: .shearwaterPetrel, serial: "D9772626") == nil)
    #expect(computers(later, ImportServer.accountB).records().isEmpty)
    #expect(inbox.files.count == 1)
    #expect(inbox.files.first?.download?.dives == 1)
  }

  @Test func aLoadDuringTheWalkNamingAnotherAccountWritesNoRecord() async throws {
    let server = try ImportServer()
    _ = try await session(server)
    let later = try await session(server, loaded: false)
    let inbox = InboxModel(session: later)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.holdBeforeEnd = true
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    let model = model(later, inbox, link)
    model.connect(try await scanned(model))
    for _ in 0..<1000 where !link.isHeld { await Task.yield() }

    server.signIn(as: ImportServer.accountB)
    try await later.loadAccount()
    inbox.sessionChanged()
    link.release()
    await model.settled()

    #expect(model.outcome?.kind == .handedOver)
    #expect(inbox.files.count == 1)
    #expect(computers(later).records().isEmpty)
    #expect(computers(later, ImportServer.accountB).records().isEmpty)
  }

  /// Waits until the fake holds, however busy the main actor is with other suites.
  private func held(_ link: FakeDiveComputerLink) async {
    await until { link.isHeld }
  }

  /// Waits until the model has taken in what the fake yielded, which it reads on its own task.
  private func until(_ condition: () -> Bool) async {
    for _ in 0..<100_000 where !condition() { await Task.yield() }
  }

  /// Moves the fake on to hold before the event at `index`, and waits for `condition`.
  private func next(
    _ link: FakeDiveComputerLink, holding index: Int?, until condition: () -> Bool = { true }
  ) async {
    link.holdBefore = index
    link.release()
    if index != nil { await held(link) }
    await until(condition)
  }

  @Test func aListingFromTheFingerprintCountsTheNewDivesAndNumbersTheDownload() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    let listing = DiveComputerListing(dives: 11, newDives: 3, newEntries: 3)
    link.scripts = [
      FakeDiveComputerLink.script(F.perdix, Array(F.perdixDownload.suffix(1))),
      FakeDiveComputerLink.script(F.perdix, listing: listing, Array(F.perdixDownload.prefix(2))),
    ]
    let model = model(session, InboxModel(session: session), link)
    try await download(model)

    // Identified, not yet listed: still connecting, the computer named.
    link.holdBefore = 1
    model.connect(try #require(model.rows.first))
    await held(link)
    await until { model.identity != nil }
    #expect(model.phase == .connecting)
    #expect(model.identity == F.perdix)
    #expect(model.downloadingText == nil)
    #expect(model.countsText == nil)
    #expect(DiveComputerButtonContent(model).accessibilityValue == "Connecting")

    await next(link, holding: 2) { model.listing != nil }
    #expect(model.phase == .downloading)
    #expect(model.countsText == "3 new dives out of 11 on this computer")
    #expect(model.downloadingText == "Downloading dive 1 of 3")
    #expect(model.progress == 0)

    await next(link, holding: 4) { model.divesDownloaded == 2 }
    #expect(model.downloadingText == "Downloading dive 3 of 3")
    #expect(model.progress == 2.0 / 3)
    #expect(
      DiveComputerButtonContent(model).accessibilityValue
        == "Downloading dive 3 of 3, 67 percent")

    await next(link, holding: nil)
    await model.settled()
    #expect(model.outcome?.sentence == "2 dives downloaded.")
    #expect(model.progress == 1)
    #expect(link.fingerprintsSet == [nil, F.fingerprint(1)])
  }

  @Test func aListingWithNoFingerprintCountsTheComputersDivesAndNeverPassesTheTotal() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    // A listing short of what the walk delivers still never reads past its total.
    link.scripts = [
      FakeDiveComputerLink.script(
        F.perdix, listing: .init(dives: 1, newDives: 1, newEntries: 1), F.perdixDownload)
    ]
    link.holdBeforeEnd = true
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { model.divesDownloaded == 3 }
    #expect(model.countsText == "1 dive on this computer")
    #expect(model.downloadingText == "Downloading dive 1 of 1")
    #expect(model.progress == 1)
    link.release()
    await model.settled()
    #expect(model.outcome?.kind == .handedOver)
  }

  @Test func skippedEntriesFillTheBarButNotTheCounter() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    let sports = [
      NauticEntrySport(id: 0x13, sport: 3), NauticEntrySport(id: 0x12, sport: 51),
      NauticEntrySport(id: 0x11, sport: 51),
    ]
    link.scripts = [
      [
        .identified(F.ocean), .watchZone(F.helsinki),
        .listing(.init(dives: 2, newDives: 2, newEntries: 3, sports: sports)),
        .skipped(fingerprint: F.fingerprint(0x13)),
      ] + F.oceanDownload.map { .dive($0) } + [.finished(.init(.complete))]
    ]
    link.holdBefore = 4
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { (model.progress ?? 0) > 0 }
    #expect(model.progress == 1.0 / 3)
    #expect(model.downloadingText == "Downloading dive 1 of 2")
    #expect(model.countsText == "2 dives on this computer")
    await next(link, holding: nil)
    await model.settled()
    #expect(model.outcome?.sentence == "2 dives downloaded.")
    let record = computers(session).record(family: .suuntoNautic, serial: "253810000400")
    #expect(record?.fingerprint == F.fingerprint(0x13))
    #expect(record?.nauticSports == sports)
  }

  /// A walk that lists no new dive keeps the connecting state and says what the computer holds;
  /// what it learned of the entries is kept although nothing was walked, and handed to the next.
  @Test func aListingOfNoNewDiveSaysHowManyTheComputerHoldsAndKeepsTheSports() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    let before = [NauticEntrySport(id: 0x12, sport: 51)]
    let after = [NauticEntrySport(id: 0x14, sport: 3)] + before
    link.scripts = [
      FakeDiveComputerLink.script(F.ocean, Array(F.oceanDownload.prefix(1)), zone: F.helsinki),
      [
        .identified(F.ocean), .listing(.init(dives: 1, newDives: 0, newEntries: 1, sports: before)),
        .skipped(fingerprint: F.fingerprint(0x13)), .finished(.init(.complete)),
      ],
      [
        .identified(F.ocean), .listing(.init(dives: 1, newDives: 0, newEntries: 0, sports: after)),
        .finished(.init(.complete)),
      ],
      [
        .identified(F.ocean), .listing(.init(dives: 1, newDives: 0, newEntries: 0, sports: after)),
        .finished(.init(.cancelled)),
      ],
    ]
    let model = model(session, InboxModel(session: session), link)
    let ocean = { computers(session).record(family: .suuntoNautic, serial: "253810000400") }
    try await download(model)
    #expect(ocean()?.nauticSports == nil)

    link.holdBefore = 3
    model.connect(try #require(model.rows.first))
    await held(link)
    await until { (model.progress ?? 0) > 0 }
    #expect(model.listing?.newDives == 0)
    #expect(model.phase == .connecting)
    #expect(model.downloadingText == nil)
    #expect(model.countsText == nil)
    await next(link, holding: nil)
    await model.settled()
    #expect(model.outcome?.kind == .nothingNew)
    #expect(
      model.outcome?.sentence == "No new dives since 25 October. 1 dive on this computer.")
    #expect(ocean()?.fingerprint == F.fingerprint(0x13))
    #expect(ocean()?.nauticSports == before)

    // Nothing walked, an entry learned: the record keeps it.
    try await download(model)
    #expect(model.outcome?.kind == .nothingNew)
    #expect(ocean()?.nauticSports == after)
    #expect(ocean()?.fingerprint == F.fingerprint(0x13))

    // A cancelled walk writes none of what it learned.
    var record = try #require(ocean())
    record.nauticSports = before
    try computers(session).save(record)
    try await download(model)
    #expect(ocean()?.nauticSports == before)
    #expect(link.sportsRemembered == [nil, nil, before, before])
  }

  @Test func aBusyComputerIsWaitedForUntilItSaysItIsFree() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    link.scripts = [
      [
        .identified(F.ocean), .watchZone(F.helsinki), .busy(true), .busy(false),
        .listing(.init(dives: 2, newDives: 2, newEntries: 2)),
      ] + F.oceanDownload.map { .dive($0) } + [.finished(.init(.complete))]
    ]
    link.holdBefore = 3
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { model.computerBusy }
    #expect(model.phase == .connecting)
    #expect(model.waitingText == "This computer is busy. The download starts when it is free.")
    let content = DiveComputerButtonContent(model)
    #expect(content.ring == .indeterminate)
    #expect(content.state == .working)
    #expect(content.accessibilityValue == model.waitingText)

    await next(link, holding: 4) { !model.computerBusy }
    #expect(model.phase == .connecting)
    #expect(model.waitingText == nil)
    #expect(DiveComputerButtonContent(model).accessibilityValue == "Connecting")
    await next(link, holding: nil)
    await model.settled()
    #expect(model.outcome?.sentence == "2 dives downloaded.")
  }

  @Test func withoutAListingTheScreenReadsAsBeforeOnceTheWalkStarts() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    link.holdBefore = 1
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { model.identity != nil }
    #expect(model.phase == .connecting)
    await next(link, holding: 3) { model.divesDownloaded == 1 }
    #expect(model.phase == .downloading)
    #expect(model.countsText == nil)
    #expect(model.downloadingText == "Downloading dive 2")
    #expect(model.progress == 0.25)
    await next(link, holding: nil)
    await model.settled()
    #expect(model.outcome?.kind == .handedOver)
  }

  private func startedAt(_ inbox: InboxModel, _ file: InboxFile) throws -> [String?] {
    let reader = try ZipReader(try #require(inbox.url(for: file)))
    let entry = try #require(reader.entries.first { $0.name == "logbook.divejson" })
    let json = try #require(ArchiveJSON.parse(try reader.read(entry)))
    return (json["dives"]?.arrayValue ?? []).map { $0["started_at"]?.stringValue }
  }
}

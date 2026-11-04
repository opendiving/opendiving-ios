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
    // Paired at the connection, its fingerprint unmoved.
    let record = computers(session).record(family: .suuntoNautic, serial: "253810000400")
    #expect(record != nil)
    #expect(record?.fingerprint == nil)
  }

  @Test func aNauticWalkThatFailsBeforeAnyDiveSaysWhereItStopped() async throws {
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
    #expect(model.outcome?.sentence == "The download stopped: DC_STATUS_PROTOCOL.")
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
    let listing = DiveComputerListing(dives: 11, newDives: 3)
    link.scripts = [
      FakeDiveComputerLink.script(F.perdix, Array(F.perdixDownload.suffix(1))),
      FakeDiveComputerLink.script(F.perdix, listing: listing, Array(F.perdixDownload.prefix(2))),
    ]
    let model = model(session, InboxModel(session: session), link)
    try await download(model)

    // Not yet identified: connecting.
    link.holdBefore = 0
    model.connect(try #require(model.rows.first))
    await held(link)
    #expect(model.phase == .connecting)
    #expect(model.connectingText == "Connecting")
    #expect(DiveComputerButtonContent(model).accessibilityValue == "Connecting")

    // Identified, not yet listed: still connecting, the computer named, reading.
    await next(link, holding: 1) { model.identity != nil }
    #expect(model.phase == .connecting)
    #expect(model.identity == F.perdix)
    #expect(model.connectingText == "Reading")
    #expect(model.downloadingText == nil)
    #expect(model.countsText == nil)
    #expect(DiveComputerButtonContent(model).accessibilityValue == "Reading")

    await next(link, holding: 2) { model.listing != nil }
    #expect(model.phase == .downloading)
    #expect(model.countsText == "3 new dives out of 11 on this computer")
    #expect(model.downloadingText == "Downloading 1 of 3 new dives")
    #expect(model.progress == DiveComputerModel.startingProgress)

    await next(link, holding: 4) { model.divesDownloaded == 2 }
    #expect(model.downloadingText == "Downloading 3 of 3 new dives")
    #expect(model.progress == 2.0 / 3)
    #expect(
      DiveComputerButtonContent(model).accessibilityValue
        == "Downloading 3 of 3 new dives, 67 percent")

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
        F.perdix, listing: .init(dives: 1, newDives: 1), F.perdixDownload)
    ]
    link.holdBeforeEnd = true
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { model.divesDownloaded == 3 }
    #expect(model.countsText == "1 dive on this computer")
    #expect(model.downloadingText == "Downloading 1 of 1 new dive")
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
        .listing(.init(dives: 2, newDives: 2, sports: sports)),
        .skipped(fingerprint: F.fingerprint(0x13)),
      ] + F.oceanDownload.map { .dive($0) } + [.finished(.init(.complete))]
    ]
    link.holdBefore = 4
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { model.phase == .downloading }
    #expect(model.downloadingText == "Downloading 1 of 2 new dives")
    #expect(model.countsText == "2 dives on this computer")
    // The skipped run moves nothing: the bar counts the dives, as the line does.
    await next(link, holding: 5) { model.divesDownloaded == 1 }
    #expect(model.progress == 0.5)
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
        .identified(F.ocean), .listing(.init(dives: 1, newDives: 0, sports: before)),
        .skipped(fingerprint: F.fingerprint(0x13)), .finished(.init(.complete)),
      ],
      [
        .identified(F.ocean), .listing(.init(dives: 1, newDives: 0, sports: after)),
        .finished(.init(.complete)),
      ],
      [
        .identified(F.ocean), .listing(.init(dives: 1, newDives: 0, sports: after)),
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
    await until { model.listing != nil }
    #expect(model.listing?.newDives == 0)
    #expect(model.phase == .connecting)
    #expect(model.connectingText == "Reading")
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

    // A walk cancelled past its listing keeps what it learned, and moves no fingerprint.
    var record = try #require(ocean())
    record.nauticSports = before
    try computers(session).save(record)
    try await download(model)
    #expect(model.outcome?.kind == .cancelled)
    #expect(ocean()?.nauticSports == after)
    #expect(ocean()?.fingerprint == F.fingerprint(0x13))
    #expect(link.sportsRemembered == [nil, nil, before, before])
  }

  /// A walk that listed pairs the computer however it ends, with what it learned, and moves no
  /// fingerprint unless it completed; one that ends before its listing has paired it at the
  /// connection.
  @Test func aWalkCancelledOrFailedPastItsListingPairsTheComputer() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    let first: [NauticEntrySport] = [
      NauticEntrySport(id: 0x13, sport: 3), NauticEntrySport(id: 0x12, sport: 51),
    ]
    let second: [NauticEntrySport] = [NauticEntrySport(id: 0x14, sport: 51)] + first
    link.scripts = [
      [
        .identified(F.ocean), .watchZone(F.helsinki),
        .listing(.init(dives: 1, newDives: 1, sports: first)),
        .finished(.init(.cancelled)),
      ],
      [
        .identified(F.ocean),
        .listing(.init(dives: 2, newDives: 2, sports: second)),
        .finished(.init(.failed(status: "DC_STATUS_IO"))),
      ],
      [.identified(F.ocean), .finished(.init(.cancelled))],
    ]
    let model = model(session, InboxModel(session: session), link)
    let ocean = { computers(session).record(family: .suuntoNautic, serial: "253810000400") }

    try await download(model)
    #expect(model.outcome?.kind == .cancelled)
    let paired = try #require(ocean())
    #expect(paired.fingerprint == nil)
    #expect(paired.lastDownloaded == nil)
    #expect(paired.nauticSports == first)
    #expect(paired.watchZone == F.helsinki)
    #expect(paired.peripheral == F.oceanFound.id)
    #expect(model.paired.map(\.title) == ["Suunto Ocean"])

    try await download(model)
    #expect(model.outcome?.kind == .failed)
    #expect(ocean()?.nauticSports == second)
    #expect(ocean()?.fingerprint == nil)
    #expect(link.sportsRemembered == [nil, first])
    #expect(link.fingerprintsSet == [nil, nil])

    computers(session).forget(try #require(ocean()))
    try await download(model)
    #expect(model.outcome?.kind == .cancelled)
    #expect(ocean() != nil)
    #expect(ocean()?.fingerprint == nil)
    #expect(ocean()?.nauticSports == nil)
  }

  @Test func aCancelledTimeZoneQuestionStillPairsTheComputer() async throws {
    let session = try await session(try ImportServer())
    let inbox = InboxModel(session: session)
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    let sports: [NauticEntrySport] = [
      NauticEntrySport(id: 0x12, sport: 51), NauticEntrySport(id: 0x11, sport: 51),
    ]
    link.scripts = [
      FakeDiveComputerLink.script(
        F.ocean, listing: .init(dives: 2, newDives: 2, sports: sports),
        F.oceanDownload)
    ]
    let model = model(session, inbox, link)
    model.connect(try await scanned(model))
    await until { model.phase == .askingTimeZone }
    #expect(model.phase == .askingTimeZone)
    model.cancel()
    await model.settled()

    #expect(model.outcome?.kind == .cancelled)
    #expect(inbox.files.isEmpty)
    let record = try #require(
      computers(session).record(family: .suuntoNautic, serial: "253810000400"))
    #expect(record.fingerprint == nil)
    #expect(record.lastDownloaded == nil)
    #expect(record.diverZone == nil)
    #expect(record.nauticSports == sports)
  }

  /// The record's sports reach the walk whether or not it has a fingerprint to set, and under
  /// *Download all dives*; no fingerprint is set in either case.
  @Test func rememberedSportsReachTheWalkWithNoFingerprintToSet() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    let sports: [NauticEntrySport] = [
      NauticEntrySport(id: 0x14, sport: 3), NauticEntrySport(id: 0x13, sport: 51),
    ]
    let skipsTheRun: [DiveComputerDownloadEvent] = [
      .identified(F.ocean),
      .listing(.init(dives: 1, newDives: 0, sports: sports)),
      .skipped(fingerprint: F.fingerprint(0x14)), .finished(.init(.complete)),
    ]
    let nothingNew: [DiveComputerDownloadEvent] = [
      .identified(F.ocean),
      .listing(.init(dives: 1, newDives: 0, sports: sports)),
      .finished(.init(.complete)),
    ]
    link.scripts = [skipsTheRun, skipsTheRun, nothingNew]
    var record = DiveComputerRecord(identity: F.ocean)
    record.nauticSports = sports
    try computers(session).save(record)
    let model = model(session, InboxModel(session: session), link)
    let ocean = { computers(session).record(family: .suuntoNautic, serial: "253810000400") }

    // Sports and no fingerprint.
    try await download(model)
    #expect(ocean()?.fingerprint == F.fingerprint(0x14))

    // *Download all dives next time* set.
    var all = try #require(ocean())
    all.downloadAllNextTime = true
    try computers(session).save(all)
    try await download(model)
    #expect(ocean()?.downloadAllNextTime == false)

    // A fingerprint to set, then *Download all dives*.
    try await download(model)
    #expect(model.outcome?.kind == .nothingNew)
    model.downloadAll()
    await model.settled()

    let set: [Data?] = [nil, nil, F.fingerprint(0x14), nil]
    #expect(link.fingerprintsSet == set)
    let remembered: [[NauticEntrySport]?] = [sports, sports, sports, sports]
    #expect(link.sportsRemembered == remembered)
  }

  @Test func aBusyComputerIsWaitedForUntilItSaysItIsFree() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    link.scripts = [
      [
        .identified(F.ocean), .watchZone(F.helsinki), .busy(.reported), .busy(.free),
        .listing(.init(dives: 2, newDives: 2)),
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
    #expect(model.connectingText == "Reading")
    #expect(DiveComputerButtonContent(model).accessibilityValue == "Reading")
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

  @Test func aWalkKeepsTheHardwareItReadAndALaterWalkThatReadsNoneLeavesIt() async throws {
    let session = try await session(try ImportServer())
    let identified = DiveComputerIdentity(
      family: F.perdix.family, vendor: F.perdix.vendor, product: F.perdix.product,
      serial: F.perdix.serial, firmware: F.perdix.firmware, hardware: "0B0B",
      familyNumber: F.perdix.familyNumber, modelNumber: F.perdix.modelNumber)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [
      FakeDiveComputerLink.script(
        identified, listing: .init(dives: 3, newDives: 0), []),
      FakeDiveComputerLink.script(
        F.perdix, listing: .init(dives: 3, newDives: 0), []),
    ]
    let model = model(session, InboxModel(session: session), link)
    for _ in 0..<2 {
      model.connect(try await scanned(model))
      await model.settled()
      let record = computers(session).record(family: .shearwaterPetrel, serial: "D9772626")
      #expect(record?.hardware == "0B0B")
    }
  }

  @Test func forgettingAComputerTheScanSeesPutsItAmongTheFound() async throws {
    let session = try await session(try ImportServer())
    let record = DiveComputerRecord(identity: F.perdix, peripheral: F.perdixFound.id)
    try computers(session).save(record)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    let model = model(session, InboxModel(session: session), link)
    _ = try await scanned(model)
    #expect(model.paired.map(\.id) == [record.id])
    #expect(model.unpairedRows.isEmpty)

    model.forget(record)
    #expect(model.paired.isEmpty)
    #expect(model.unpairedRows.map(\.computer) == [F.perdixFound])
    #expect(computers(session).record(family: .shearwaterPetrel, serial: "D9772626") == nil)
  }

  /// The record is saved once the computer is identified, so Settings lists it while the first
  /// download runs.
  @Test func aConnectionPairsTheComputerWhileTheFirstDownloadRuns() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [
      FakeDiveComputerLink.script(
        F.perdix, listing: .init(dives: 3, newDives: 3), F.perdixDownload)
    ]
    link.holdBefore = 1
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { model.identity != nil }
    let record = computers(session).record(family: .shearwaterPetrel, serial: "D9772626")
    #expect(record != nil)
    #expect(record?.fingerprint == nil)
    #expect(record?.peripheral == F.perdixFound.id)
    #expect(model.paired.map(\.title) == ["Shearwater Perdix 3"])
    #expect(
      DiveComputersListModel(session: session).computers.map(\.title) == ["Shearwater Perdix 3"])

    await next(link, holding: nil)
    await model.settled()
    #expect(model.outcome?.kind == .handedOver)
    let kept = computers(session).record(family: .shearwaterPetrel, serial: "D9772626")
    #expect(kept?.fingerprint == F.fingerprint(3))
  }

  /// A computer that says it is busy while the download runs shows the waiting line in place of
  /// the counter, which says the download continues once a dive has downloaded.
  @Test func aBusyWatchDuringTheDownloadShowsTheWaitingLineInPlaceOfTheCounter() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    let dives = F.oceanDownload
    link.scripts = [
      [
        .identified(F.ocean), .watchZone(F.helsinki),
        .listing(.init(dives: 2, newDives: 2)), .busy(.reported), .busy(.free),
        .dive(dives[0]), .busy(.reported), .busy(.free), .dive(dives[1]),
        .finished(.init(.complete)),
      ]
    ]
    link.holdBefore = 4
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { model.computerBusy }
    #expect(model.phase == .downloading)
    #expect(model.waitingText == "This computer is busy. The download starts when it is free.")
    #expect(model.progress == DiveComputerModel.startingProgress)
    let before = DiveComputerButtonContent(model)
    #expect(before.ring == .fraction(DiveComputerModel.startingProgress))
    #expect(before.accessibilityValue == model.waitingText)

    await next(link, holding: 7) { model.divesDownloaded == 1 && model.computerBusy }
    #expect(
      model.waitingText == "This computer is busy. The download continues when it is free.")
    #expect(model.progress == 0.5)
    #expect(DiveComputerButtonContent(model).accessibilityValue == model.waitingText)

    await next(link, holding: 8) { !model.computerBusy }
    #expect(model.waitingText == nil)
    #expect(model.downloadingText == "Downloading 2 of 2 new dives")
    await next(link, holding: nil)
    await model.settled()
    #expect(model.outcome?.sentence == "2 dives downloaded.")
  }

  /// Once another app's handshake broke a transfer, connecting or downloading, the waiting line
  /// names what frees the computer, in place of the counter, and stays through the retries and
  /// the listing until a dive arrives.
  @Test func anotherAppsHandshakeShowsItsLineUntilADiveArrives() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.oceanFound]
    let dives = F.oceanDownload
    link.scripts = [
      [
        .identified(F.ocean), .watchZone(F.helsinki), .busy(.otherApp),
        .listing(.init(dives: 2, newDives: 2)), .busy(.otherApp),
        .dive(dives[0]), .busy(.otherApp), .dive(dives[1]), .finished(.init(.complete)),
      ]
    ]
    let line = "This computer is busy. Closing other apps that use it lets the download go on."
    link.holdBefore = 3
    let model = model(session, InboxModel(session: session), link)
    model.connect(try await scanned(model))
    await held(link)
    await until { model.otherAppHandshaking }
    #expect(model.phase == .connecting)
    #expect(model.waitingText == line)
    #expect(DiveComputerButtonContent(model).accessibilityValue == line)

    await next(link, holding: 5) { model.listing != nil }
    #expect(model.phase == .downloading)
    #expect(model.waitingText == line)
    #expect(DiveComputerButtonContent(model).accessibilityValue == line)

    await next(link, holding: 6) { model.divesDownloaded == 1 }
    #expect(!model.otherAppHandshaking)
    #expect(model.waitingText == nil)
    #expect(model.downloadingText == "Downloading 2 of 2 new dives")

    await next(link, holding: 7) { model.otherAppHandshaking }
    #expect(model.waitingText == line)
    await next(link, holding: nil)
    await model.settled()
    #expect(model.outcome?.sentence == "2 dives downloaded.")
  }

  /// The walk is handed the dives of the download archives waiting under its own mark; a refused
  /// reading carries no uuid there, so it is downloaded again.
  @Test func aDiveWaitingUnderTheWalksMarkReachesTheWalkAsWaiting() async throws {
    let server = try ImportServer()
    let first = try await session(server)
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [FakeDiveComputerLink.script(F.perdix, F.perdixDownload)]
    let model = model(first, InboxModel(session: first), link)
    try await download(model)
    try await download(model)
    #expect(!link.waitingTests[0](F.perdix, F.fingerprint(3)))
    let waiting = link.waitingTests[1]
    #expect(waiting(F.perdix, F.fingerprint(3)))
    #expect(waiting(F.perdix, F.fingerprint(2)))
    #expect(!waiting(F.perdix, F.fingerprint(1)))
    #expect(!waiting(F.ocean, F.fingerprint(3)))

    // Signed in again before the account loads: the marked inbox's walk is not told them.
    let later = try await session(server, loaded: false)
    try await download(self.model(later, InboxModel(session: later), link))
    #expect(!link.waitingTests[2](F.perdix, F.fingerprint(3)))
  }

  /// A completed walk whose every new dive already waits says so, offers *Download all dives*,
  /// and moves the fingerprint past them.
  @Test func aWalkWhoseEveryNewDiveIsWaitingSaysSo() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    let one: [DiveComputerDownloadEvent] = [
      .identified(F.perdix), .listing(.init(dives: 11, newDives: 0)),
      .skipped(fingerprint: F.fingerprint(4)), .finished(.init(.complete, waiting: 1)),
    ]
    let two: [DiveComputerDownloadEvent] = [
      .identified(F.perdix), .listing(.init(dives: 11, newDives: 0)),
      .skipped(fingerprint: F.fingerprint(5)), .skipped(fingerprint: F.fingerprint(4)),
      .finished(.init(.complete, waiting: 2)),
    ]
    link.scripts = [one, two]
    let model = model(session, InboxModel(session: session), link)

    // Without a fingerprint.
    try await download(model)
    #expect(model.outcome?.kind == .alreadyWaiting)
    #expect(
      model.outcome?.sentence
        == "The new dive is already waiting in the import screen. 11 dives on this computer.")
    #expect(model.outcome?.offersDownloadAll == true)
    let perdix = { computers(session).record(family: .shearwaterPetrel, serial: "D9772626") }
    #expect(perdix()?.fingerprint == F.fingerprint(4))

    // With one.
    try await download(model)
    #expect(model.outcome?.kind == .alreadyWaiting)
    #expect(
      model.outcome?.sentence
        == "The new dives are already waiting in the import screen. 11 dives on this computer.")
    #expect(perdix()?.fingerprint == F.fingerprint(5))

    // Under *Download all dives*.
    model.downloadAll()
    await model.settled()
    #expect(model.outcome?.kind == .alreadyWaiting)
    let set: [Data?] = [nil, F.fingerprint(4), nil]
    #expect(link.fingerprintsSet == set)
  }

  @Test func entriesThatCouldNotBeDownloadedAreNamedInTheOutcome() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    let dives = F.perdixDownload
    link.scripts = [
      [
        .identified(F.perdix), .listing(.init(dives: 3, newDives: 3)),
        .dive(dives[0]), .skipped(fingerprint: F.fingerprint(7)), .dive(dives[1]),
        .finished(.init(.complete, notDownloaded: 1)),
      ],
      [
        .identified(F.perdix), .listing(.init(dives: 5, newDives: 2)),
        .skipped(fingerprint: F.fingerprint(9)), .skipped(fingerprint: F.fingerprint(8)),
        .finished(.init(.failed(status: "DC_STATUS_TIMEOUT"), notDownloaded: 2)),
      ],
    ]
    let model = model(session, InboxModel(session: session), link)
    try await download(model)
    #expect(model.outcome?.sentence == "2 dives downloaded. 1 dive couldn't be downloaded.")
    #expect(model.outcome?.offersDownloadAll == false)
    try await download(model)
    #expect(
      model.outcome?.sentence
        == "The download stopped: DC_STATUS_TIMEOUT. 2 dives couldn't be downloaded.")
  }

  /// A completed walk that delivered nothing and left entries out says neither that there are no
  /// dives nor that there are none new, and offers *Download all dives*, which tries them again.
  @Test func aWalkThatOnlyLeftEntriesOutSaysSoAndOffersDownloadAll() async throws {
    let session = try await session(try ImportServer())
    let link = FakeDiveComputerLink()
    link.found = [F.perdixFound]
    link.scripts = [
      [
        .identified(F.perdix), .listing(.init(dives: 3, newDives: 1)),
        .skipped(fingerprint: F.fingerprint(7)), .finished(.init(.complete, notDownloaded: 1)),
      ],
      [
        .identified(F.perdix), .listing(.init(dives: 3, newDives: 1)),
        .skipped(fingerprint: F.fingerprint(8)), .skipped(fingerprint: F.fingerprint(7)),
        .finished(.init(.complete, waiting: 1, notDownloaded: 1)),
      ],
    ]
    let model = model(session, InboxModel(session: session), link)
    try await download(model)
    #expect(model.outcome?.kind == .notDownloaded)
    #expect(
      model.outcome?.sentence == "1 dive couldn't be downloaded. 3 dives on this computer.")
    #expect(model.outcome?.offersDownloadAll == true)
    #expect(DiveComputerButtonContent(model).state == .failed)

    model.downloadAll()
    await model.settled()
    #expect(
      model.outcome?.sentence
        == "The new dive is already waiting in the import screen. 1 dive couldn't be downloaded."
        + " 3 dives on this computer.")
    let set: [Data?] = [nil, nil]
    #expect(link.fingerprintsSet == set)
  }

  private func startedAt(_ inbox: InboxModel, _ file: InboxFile) throws -> [String?] {
    let reader = try ZipReader(try #require(inbox.url(for: file)))
    let entry = try #require(reader.entries.first { $0.name == "logbook.divejson" })
    let json = try #require(ArchiveJSON.parse(try reader.read(entry)))
    return (json["dives"]?.arrayValue ?? []).map { $0["started_at"]?.stringValue }
  }
}

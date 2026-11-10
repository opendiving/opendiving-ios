import Foundation
import OpenDivingKit
import SwiftUI
import Testing

@testable import OpenDiving

/// The pending section and screen over stores a session wrote, signed in and signed out, and
/// the forget confirmation's count of what they hold.
@MainActor
struct PendingTests {
  private typealias F = OfflineFixtures

  /// A session signed in as `account`, its account loaded, whose writes are refused with a
  /// 422 while `online` is on and find no route while it is off.
  private func loaded(_ directory: URL, online: Flag, as account: String = F.accountA)
    async throws -> Session
  {
    let session = F.signedIn(
      directory,
      transport: StubTransport { request in
        if let answer = F.account(request, as: account) { return answer }
        let method = request.httpMethod ?? "GET"
        guard method == "POST" || method == "PATCH" else { return F.notFound }
        guard online.isOn else { throw URLError(.notConnectedToInternet) }
        return .json(#"{"detail":"A dive site of this name exists."}"#, status: 422)
      })
    try await session.loadAccount()
    return session
  }

  private func dive(_ number: Int = 1) -> OutboxOperation {
    .createDive(DiveCreate(diveNumber: number, startTime: F.start, submergedTime: 2400))
  }

  @Test func theSectionCountsWhatTheStoresHold() async throws {
    let online = Flag(true)
    let session = try await loaded(F.directory(), online: online)
    let outbox = OutboxModel(session: session)
    let inbox = InboxModel(session: session)

    let refused = try outbox.queue(.createDiveSite(DiveSiteCreate(name: "Blue Hole")))
    await outbox.settled()
    online.set(false)
    try outbox.queue(.createDiveSite(DiveSiteCreate(name: "Lighthouse")))
    try outbox.queue(.createPerson(PersonCreate(name: "Sam")))
    try outbox.queue(dive())
    await outbox.settled()
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).fit")
    try Data([0x0e, 0x10]).write(to: file)
    _ = inbox.receive([file], moving: false)
    await inbox.settled()

    #expect(
      PendingSection.summary(outbox, inbox).rows.map(\.text) == [
        "A dive, a site and a buddy waiting to sync", "1 could not be saved", "1 file waiting",
      ])
    let failed = try #require(outbox.item(refused.id))
    #expect(failed.failure?.message == "A dive site of this name exists.")
    #expect(PendingScreen.edit(failed) == .sheet(.diveSite(failed.id)))

    let window = F.window(
      NavigationStack { PendingScreen() }
        .environment(session).environment(outbox).environment(inbox))
    defer { window?.isHidden = true }
    #expect(window != nil)
  }

  @Test func aFileWaitsToUploadThenShowsAsUploadedAndSyncNowSendsNothingOfTheInbox() async throws {
    let uploads = Counter()
    let session = F.signedIn(
      F.directory(),
      transport: StubTransport { request in
        if let answer = F.account(request) { return answer }
        guard StubTransport.routeKey(request) == "POST imports" else { return F.notFound }
        _ = uploads.next()
        return .json(
          #"{"uuid":"01a1b5d5-0182-786a-bc62-ed7fe7907b7d","status":"pending","#
            + #""created_at":"2026-11-07T11:46:38+00:00","applied_at":null,"expires_at":null,"#
            + #""archive":false,"collections":[],"#
            + #""files":{"referenced":0,"restored":0,"not_contained":0,"skipped":0},"#
            + #""members":[{"part":0,"container":null,"name":"dive.fit","byte_size":2,"#
            + #""sha256":"00","format":"fit","opened":null,"kept":true,"not_kept":null,"#
            + #""refusal":null}],"dives":[],"check_in_details":[],"portrait":null,"#
            + #""numbering":{"total_dives":0,"lowest":null,"highest":null,"missing_count":0,"#
            + #""duplicate_count":0,"out_of_date_order_count":0,"is_sequential":false}}"#,
          status: 201)
      })
    try await session.loadAccount()
    let outbox = OutboxModel(session: session)
    let inbox = InboxModel(session: session)
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).fit")
    try Data([0x0e, 0x10]).write(to: file)
    _ = inbox.receive([file], moving: false)
    await inbox.settled()

    #expect(inbox.files.map(inbox.stage(of:)).map(PendingText.fileStage) == ["Waiting to upload"])
    #expect(PendingScreen.filesFooter(inbox) == nil)
    outbox.syncNow()
    await outbox.settled()
    #expect(uploads.next() == 0)

    inbox.upload()
    await inbox.settled()
    #expect(
      inbox.files.map(inbox.stage(of:)).map(PendingText.fileStage) == [
        "Uploaded, waiting for the import to be finished"
      ])
    #expect(uploads.next() == 2)

    let window = F.window(
      NavigationStack { PendingScreen() }
        .environment(session).environment(outbox).environment(inbox))
    defer { window?.isHidden = true }
    #expect(window != nil)

    let screen = F.window(
      NavigationStack { ImportView() }.environment(session).environment(inbox))
    defer { screen?.isHidden = true }
    #expect(screen != nil)
  }

  @Test func anEmptyOutboxDrawsNoSection() async throws {
    let session = try await loaded(F.directory(), online: Flag(true))
    let outbox = OutboxModel(session: session)
    #expect(PendingSection.summary(outbox, InboxModel(session: session)).isEmpty)
  }

  @Test func editOpensTheFormOnARefusedDiveAndNothingOnAnAttemptedCreate() async throws {
    let online = Flag(true)
    let session = try await loaded(F.directory(), online: online)
    let outbox = OutboxModel(session: session)
    let refused = try outbox.queue(dive(1))
    await outbox.settled()
    #expect(PendingScreen.edit(try #require(outbox.item(refused.id))) == .form(.failed(refused.id)))

    online.set(false)
    let attempted = try outbox.queue(dive(2))
    await outbox.settled()
    let item = try #require(outbox.item(attempted.id))
    #expect(item.lastAnswer == .unreachable)
    #expect(PendingScreen.edit(item) == nil)
    #expect(item.isDiscardable)
  }

  @Test func editReopensARefusedTripOrSiteEditAndNothingStillWaiting() async throws {
    let online = Flag(true)
    let session = try await loaded(F.directory(), online: online)
    let outbox = OutboxModel(session: session)
    let (tripUUID, siteUUID) = (UUID(), UUID())
    var update = DiveSiteUpdate()
    update.name = "Lighthouse"
    let trip = try outbox.queue(.updateTrip(.server(tripUUID), TripUpdate(name: "Dahab")))
    let site = try outbox.queue(.updateDiveSite(.server(siteUUID), update))
    await outbox.settled()
    #expect(
      PendingScreen.edit(try #require(outbox.item(trip.id)))
        == .trip(.failed(item: trip.id, record: tripUUID)))
    #expect(
      PendingScreen.edit(try #require(outbox.item(site.id)))
        == .diveSite(.failed(item: site.id, record: siteUUID)))

    online.set(false)
    let waiting = try outbox.queue(.updateTrip(.server(UUID()), TripUpdate(name: "Sinai")))
    let deleted = try outbox.queue(.deleteDive(.server(UUID())))
    await outbox.settled()
    for id in [waiting.id, deleted.id] {
      let item = try #require(outbox.item(id))
      #expect(PendingScreen.edit(item) == nil)
      #expect(item.isDiscardable)
    }
  }

  @Test func editReopensEachRefusedWriteOfMoresRecordsInItsForm() async throws {
    let session = try await loaded(F.directory(), online: Flag(true))
    let outbox = OutboxModel(session: session)
    let gear = RecordRef.server(UUID())
    let day = CalendarDate(year: 2026, month: 10, day: 2)!
    var rename = GearItemUpdate()
    rename.name = "Twin set"
    var moved = GearServiceScheduleUpdate()
    moved.startsOn = day
    typealias Write = (
      operation: (RecordRef) -> OutboxOperation, edit: (_ item: UUID, _ record: UUID) -> PendingEdit
    )
    let writes: [Write] = [
      (
        { .updatePerson($0, PersonUpdate(name: "Sam")) },
        { .route(.person(.failed(item: $0, record: $1))) }
      ),
      ({ .updateCourse($0, CourseUpdate()) }, { .route(.course(.failed(item: $0, record: $1))) }),
      (
        { .updateContact($0, ContactUpdate()) }, { .route(.contact(.failed(item: $0, record: $1))) }
      ),
      (
        { .updateGearItem($0, rename) },
        { .route(.gearItem(.failed(item: $0, record: $1))) }
      ),
      (
        { .updateCertification($0, CertificationUpdate()) },
        { .route(.certification(.failed(item: $0, record: $1), failedItem: nil)) }
      ),
      (
        { .updateServiceSchedule($0, gearItem: gear, moved) },
        { .route(.serviceSchedule(gearItem: gear, .failed(item: $0, record: $1), failedItem: nil)) }
      ),
      (
        { .updateServiceRecord($0, gearItem: gear, GearServiceRecordUpdate()) },
        { .route(.serviceRecord(gearItem: gear, .failed(item: $0, record: $1), failedItem: nil)) }
      ),
      (
        { _ in .createCertification(CertificationCreate(agency: "padi", name: "Rescue")) },
        { item, _ in .route(.certification(.create, failedItem: item)) }
      ),
      (
        { _ in
          .createServiceSchedule(
            GearServiceScheduleCreate(gearItem: gear, kind: "service", startsOn: day))
        },
        { item, _ in .route(.serviceSchedule(gearItem: gear, .create, failedItem: item)) }
      ),
      (
        { _ in
          .createServiceRecord(
            GearServiceRecordCreate(gearItem: gear, kind: "service", servicedOn: day))
        },
        { item, _ in .route(.serviceRecord(gearItem: gear, .create, failedItem: item)) }
      ),
    ]
    for write in writes {
      let uuid = UUID()
      let queued = try outbox.queue(write.operation(.server(uuid)))
      await outbox.settled()
      let item = try #require(outbox.item(queued.id))
      #expect(item.isFailed)
      #expect(PendingScreen.edit(item) == write.edit(item.id, uuid))
    }
  }

  @Test func signedOutTheEmailScreenOffersTheLastAccountsPendingScreen() async throws {
    let directory = F.directory()
    let signedIn = try await loaded(directory, online: Flag(false))
    try OutboxModel(session: signedIn).queue(dive())

    let session = F.signedOut(directory)
    let flow = SignInFlow(session: session)
    #expect(flow.signedOutEntries.contains(.logDive))
    #expect(flow.signedOutEntries.contains(.waitingToSync))
    let outbox = OutboxModel(session: session)
    let inbox = InboxModel(session: session)
    #expect(
      PendingText.signedOutWaiting(
        drafts: outbox.drafts.count, items: outbox.items, unreadable: outbox.unreadable.count,
        files: inbox.files.count) == "1 dive waiting to sync")
    #expect(
      PendingSection.summary(outbox, inbox).rows.map(\.text) == ["A dive waiting to sync"])
    #expect(outbox.items.allSatisfy { !$0.writtenBeforeAccountKnown })

    let window = F.window(
      SignInView().environment(session).environment(flow).environment(outbox)
        .environment(inbox))
    defer { window?.isHidden = true }
    #expect(window != nil)

    let fresh = Session.signedOutStub(transport: StubTransport(routes: [:]))
    #expect(SignInFlow(session: fresh).signedOutEntries == [.checkInSheet])
  }

  @Test func theForgetConfirmationCountsEveryAccountsDives() async throws {
    let directory = F.directory()
    let offline = Flag(false)
    let a = try await loaded(directory, online: offline, as: F.accountA)
    try OutboxModel(session: a).queue(dive(1))
    let b = try await loaded(directory, online: offline, as: F.accountB)
    let outbox = OutboxModel(session: b)
    try outbox.queue(dive(2))
    await outbox.settled()

    let summary = OutboxStore.summary(store: b.store, origin: F.origin)
    #expect(summary.dives == 2)
    #expect(
      KeptText.forgetMessage(summary)
        == "2 dives have not been saved to the server and will be lost.")
  }
}

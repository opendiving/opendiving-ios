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

  @Test func signedOutTheEmailScreenOffersTheLastAccountsPendingScreen() async throws {
    let directory = F.directory()
    let signedIn = try await loaded(directory, online: Flag(false))
    try OutboxModel(session: signedIn).queue(dive())

    let session = F.signedOut(directory)
    let flow = SignInFlow(session: session)
    #expect(flow.signedOutEntries.contains(.waitingToSync))
    let outbox = OutboxModel(session: session)
    let inbox = InboxModel(session: session)
    #expect(
      PendingSection.summary(outbox, inbox).rows.map(\.text) == ["A dive waiting to sync"])
    #expect(outbox.items.allSatisfy { !$0.writtenBeforeAccountKnown })

    let window = F.window(
      SignInView().environment(session).environment(flow).environment(outbox)
        .environment(inbox))
    defer { window?.isHidden = true }
    #expect(window != nil)

    let fresh = Session.signedOutStub(transport: StubTransport(routes: [:]))
    #expect(!SignInFlow(session: fresh).signedOutEntries.contains(.waitingToSync))
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
      KeptText.forgetMessage(summary).contains(
        "and 2 dives that have not been saved to the server."))
  }
}

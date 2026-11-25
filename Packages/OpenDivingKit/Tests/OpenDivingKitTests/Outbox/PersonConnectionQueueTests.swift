import Foundation
import Testing

@testable import OpenDivingKit

/// A person's disconnect is queued as the person's other writes are, and a body queued with the
/// `username` a person was once linked by is sent as what it means now: a null as the disconnect,
/// any other value not at all.
@MainActor
struct PersonConnectionQueueTests {
  private static let person = UUID(uuidString: "01a0e2ed-1be6-72f8-8057-0b0caa945758")!
  private static var wire: String { APIClient.wire(person) }

  /// Writes `operation` into the outbox as a file whose body carries `username` as `value`, as a
  /// body queued before `username` left the person's requests.
  private func queueKept(
    _ operation: OutboxOperation, username value: Any, in world: OutboxWorld, sequence: Int = 1
  ) throws -> OutboxItem {
    let item = OutboxItem(operation: operation, sequence: sequence, marked: false)
    var object =
      try JSONSerialization.jsonObject(with: APICoding.encoder().encode(item)) as! [String: Any]
    var kept = object["operation"] as! [String: Any]
    var body = kept["body"] as! [String: Any]
    body["username"] = value
    kept["body"] = body
    object["operation"] = kept
    let folder = world.session.store.directory(
      for: OutboxServer.origin, account: OutboxServer.accountA
    ).appendingPathComponent("Outbox/items", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: object).write(
      to: folder.appendingPathComponent(KeptFolder<OutboxItem>.name(for: item.id)))
    return item
  }

  @Test func aDisconnectIsPostedToThePerson() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let outbox = world.outbox()
    let mark = world.server.mark
    #expect(PeopleListModel.disconnect(Self.person, in: outbox) == nil)
    await outbox.settled()
    #expect(
      world.server.writes(since: mark).map(\.route) == ["POST person/\(Self.wire)/disconnect"])
    #expect(world.server.writes(since: mark).first?.body == nil)
    #expect(outbox.items.isEmpty)
  }

  @Test func aDisconnectOfAPersonTheServerNoLongerHasIsDone() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasSuffix("/disconnect") ? .status(404, "Person not found.") : nil
    }
    let outbox = world.outbox()
    try outbox.queue(.disconnectPerson(.server(Self.person)))
    await outbox.settled()
    #expect(outbox.items.isEmpty)
  }

  @Test func aKeptUpdateThatOnlyDetachedThePersonIsSentAsTheDisconnect() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let kept = try queueKept(
      .updatePerson(.server(Self.person), PersonUpdate()), username: NSNull(), in: world)
    let items = world.storesA.items()
    #expect(items.map(\.id) == [kept.id])
    #expect(items.first?.operation == .disconnectPerson(.server(Self.person)))
    // Written back, so the next read finds the disconnect itself.
    #expect(world.storesA.items() == items)

    let mark = world.server.mark
    let outbox = world.outbox()
    outbox.syncNow()
    await outbox.settled()
    #expect(
      world.server.writes(since: mark).map(\.route) == ["POST person/\(Self.wire)/disconnect"])
  }

  @Test func aKeptUpdateThatDetachedThePersonAndChangedMoreIsFollowedByTheDisconnect()
    async throws
  {
    let world = try OutboxWorld()
    try await world.load()
    _ = try queueKept(
      .updatePerson(.server(Self.person), PersonUpdate(name: "Sam")), username: NSNull(),
      in: world)
    let later = OutboxItem(
      operation: .deletePerson(.server(Self.person)), sequence: 2, marked: false)
    try world.storesA.save(later)

    let items = world.storesA.items()
    #expect(
      items.map(\.operation) == [
        .updatePerson(.server(Self.person), PersonUpdate(name: "Sam")),
        .disconnectPerson(.server(Self.person)), .deletePerson(.server(Self.person)),
      ])
    #expect(world.storesA.items().map(\.id) == items.map(\.id))

    let mark = world.server.mark
    let outbox = world.outbox()
    outbox.syncNow()
    await outbox.settled()
    let writes = world.server.writes(since: mark)
    #expect(
      writes.map(\.route) == [
        "PATCH person/\(Self.wire)", "POST person/\(Self.wire)/disconnect",
        "DELETE person/\(Self.wire)",
      ])
    #expect(writes.first?.json.keys.sorted() == ["name"])
  }

  @Test func aKeptUsernameOfAnyOtherValueIsDroppedAndTheRestSentAsItWas() async throws {
    let world = try OutboxWorld()
    try await world.load()
    _ = try queueKept(
      .updatePerson(.server(Self.person), PersonUpdate(notes: "Boat")), username: "samr",
      in: world)
    _ = try queueKept(
      .createPerson(PersonCreate(name: "Robin")), username: "robin", in: world, sequence: 2)
    let mark = world.server.mark
    let outbox = world.outbox()
    outbox.syncNow()
    await outbox.settled()
    let writes = world.server.writes(since: mark)
    #expect(writes.map(\.route) == ["PATCH person/\(Self.wire)", "POST person"])
    #expect(writes.map { $0.json.keys.sorted() } == [["notes"], ["name", "notes"]])
  }
}

import Foundation
import OpenDivingKit
import Testing

/// A `PATCH` body tells three states apart per member, and the wire shows each.
struct DiveUpdateWireTests {
  private func sent(_ update: DiveUpdate) throws -> JSONValue {
    try JSONValue.parse(APICoding.requestEncoder().encode(update))
  }

  @Test func anUnchangedUpdateSendsAnEmptyObject() throws {
    #expect(try sent(DiveUpdate()) == .object([:]))
    #expect(DiveUpdate().isEmpty)
  }

  @Test func absentIsLeftOutNullIsNullAValueIsTheValue() throws {
    var update = DiveUpdate()
    update.maxDepth = .value(18.5)
    update.weight = .null
    update.trip = .null
    update.course = .value(.server(UUID(uuidString: "01a14b2e-0c3d-7a10-9f00-1a2b3c4d5e6f")!))
    update.notes = "Edited."
    let body = try sent(update)
    #expect(body.keys == ["max_depth", "weight", "trip_uuid", "course_uuid", "notes"])
    #expect(body["max_depth"] == .number(18.5))
    #expect(body["weight"] == .null)
    #expect(body["trip_uuid"] == .null)
    #expect(body["course_uuid"] == .string("01a14b2e-0c3d-7a10-9f00-1a2b3c4d5e6f"))
    #expect(body["avg_depth"] == nil)
    #expect(!update.isEmpty)
  }

  @Test func aListIsSentWholeWhenSetAndAnEmptyListClearsIt() throws {
    var update = DiveUpdate()
    update.diveSites = []
    update.tags = ["night"]
    let body = try sent(update)
    #expect(body["dive_site_uuids"] == .array([]))
    #expect(body["tags"] == .array([.string("night")]))
    #expect(body["mixtures"] == nil)
  }

  @Test func whatIsQueuedReadsBackAsQueued() throws {
    var update = DiveUpdate()
    update.visibility = .null
    update.rating = .value(5)
    update.gearItems = [.local(UUID())]
    let kept = try APICoding.encoder().encode(update)
    #expect(try APICoding.decoder().decode(DiveUpdate.self, from: kept) == update)
  }
}

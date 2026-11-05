import Foundation
import Testing

@testable import OpenDivingKit

/// What an edit of a trip or a dive site sends: what differs from what the form opened on, in
/// the shape the API takes it.
struct RecordEditValuesTests {
  private func trip() throws -> TripRead { try KitFixture.decode(TripRead.self, "trip") }
  private func site() throws -> DiveSiteRead {
    try KitFixture.decode(DiveSiteRead.self, "dive-site")
  }

  private func wire(_ value: some Encodable) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: APIClient.json(value))
    return try #require(object as? [String: Any])
  }

  @Test func aTripOpenedAndSavedChangesNothing() throws {
    let values = TripFormValues(editing: try trip())
    #expect(try values.diff(from: values).isEmpty)
  }

  @Test func aTripSendsOnlyWhatChanged() throws {
    let before = TripFormValues(editing: try trip())
    var after = before
    after.name = "  Dahab again "
    #expect(try after.diff(from: before) == TripUpdate(name: "Dahab again"))
  }

  @Test func aTripsLastPartRemovedClearsItsParts() throws {
    let before = TripFormValues(editing: try trip())
    #expect(!before.parts.isEmpty)
    var after = before
    after.parts = []
    #expect(try after.diff(from: before) == TripUpdate(parts: []))
    #expect(try wire(after.diff(from: before))["parts"] as? [Any] != nil)
  }

  @Test func aTripWithNoPartsOpensWithNone() throws {
    var read = try wire(KitFixture.decode(TripRead.self, "trip"))
    read["parts"] = []
    let data = try JSONSerialization.data(withJSONObject: read)
    let trip = try APICoding.decoder().decode(TripRead.self, from: data)
    #expect(TripFormValues(editing: trip).parts.isEmpty)
  }

  @Test func anInvalidTripSendsNothing() throws {
    let before = TripFormValues(editing: try trip())
    var after = before
    after.name = " "
    #expect(throws: FormInvalid.self) { try after.diff(from: before) }
  }

  @Test func aSiteOpenedAndSavedChangesNothing() throws {
    let values = DiveSiteFormValues(editing: try site())
    #expect(try values.diff(from: values).isEmpty)
  }

  @Test func aPositionIsSentAsAPairEvenWhenOneCoordinateMoved() throws {
    var before = DiveSiteFormValues(editing: try site())
    before.latitude = "28.5"
    before.longitude = "34.5"
    var after = before
    after.latitude = "28.6"
    let update = try after.diff(from: before)
    #expect(update.latitude == .value(28.6))
    #expect(update.longitude == .value(34.5))
  }

  @Test func whatIsClearedIsSentAsNullAndWhatIsNotIsLeftOut() throws {
    var before = DiveSiteFormValues(editing: try site())
    before.latitude = "28.5"
    before.longitude = "34.5"
    before.depthTo = 30
    var after = before
    after.latitude = ""
    after.longitude = ""
    after.depthTo = nil
    after.location = nil
    let body = try wire(after.diff(from: before))
    #expect(Set(body.keys) == ["latitude", "longitude", "depth_to", "location"])
    #expect(body.values.allSatisfy { $0 is NSNull })
  }

  @Test func aQueuedUpdateLaidOverReadsAsTheFormLeftIt() throws {
    let before = DiveSiteFormValues(editing: try site())
    var after = before
    after.name = "Lighthouse"
    after.latitude = "28.5"
    after.longitude = "34.5"
    after.tags = ["reef"]
    after.location = nil
    #expect(before.applying(try after.diff(from: before)) == after)

    let trip = TripFormValues(editing: try trip())
    var edited = trip
    edited.notes = "Windy"
    edited.parts = []
    #expect(trip.applying(try edited.diff(from: trip)) == edited)
  }
}

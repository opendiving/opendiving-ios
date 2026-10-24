import Foundation
import OpenDivingKit
import Testing

/// Every request body decodes its fixture — a body the API's schema accepts, holding every
/// member the schema has — and encodes, as it would be sent, to exactly that body.
struct RequestFixtureTests {
  private func sendsItsFixture<Body: Codable>(_ type: Body.Type, _ name: String) throws -> Body {
    let fixture = try KitFixture.data(name)
    let body = try APICoding.decoder().decode(type, from: fixture)
    let sent = try JSONValue.parse(APICoding.requestEncoder().encode(body))
    let expected = try JSONValue.parse(fixture)
    #expect(sent == expected, "\(name): sent \(sent)")
    return body
  }

  @Test func diveCreate() throws {
    let dive = try sendsItsFixture(DiveCreate.self, "request-dive-create")
    #expect(dive.startTime.utcOffsetMinutes == 180)
    #expect(dive.mixtures.first?.gearItem?.isLocal == false)
  }

  @Test func diveUpdate() throws {
    let update = try sendsItsFixture(DiveUpdate.self, "request-dive-update")
    #expect(update.trip == .null)
    #expect(update.avgDepth == .null)
    #expect(update.diveSites == [])
  }

  @Test func diveSiteCreate() throws {
    _ = try sendsItsFixture(DiveSiteCreate.self, "request-dive-site-create")
  }

  @Test func tripCreate() throws {
    _ = try sendsItsFixture(TripCreate.self, "request-trip-create")
  }

  @Test func gearItemCreate() throws {
    _ = try sendsItsFixture(GearItemCreate.self, "request-gear-item-create")
  }

  @Test func gearSetCreateAndUpdate() throws {
    _ = try sendsItsFixture(GearSetCreate.self, "request-gear-set-create")
    let update = try sendsItsFixture(GearSetUpdate.self, "request-gear-set-update")
    #expect(update.weight == .null)
  }

  @Test func personCreate() throws {
    _ = try sendsItsFixture(PersonCreate.self, "request-person-create")
  }

  @Test func courseCreate() throws {
    _ = try sendsItsFixture(CourseCreate.self, "request-course-create")
  }

  @Test func contactCreate() throws {
    _ = try sendsItsFixture(ContactCreate.self, "request-contact-create")
  }

  @Test func diveDraftWrite() throws {
    let draft = try sendsItsFixture(DiveDraftWrite.self, "request-dive-draft-write")
    #expect(draft.values.diveNumber == 215)
  }

  @Test func importChoices() throws {
    let checkIn = try sendsItsFixture(ImportCheckInSubmission.self, "request-import-check-in")
    #expect(checkIn.phone == .null)
    let portrait = try sendsItsFixture(ImportPortraitChoice.self, "request-import-portrait")
    #expect(portrait.take)
  }

  /// The draft's `values` carry `DiveCreate`'s members and no others, so a member added to one
  /// is a member added to both.
  @Test func aDraftsValuesAreADivesMembers() throws {
    let create = try JSONValue.parse(KitFixture.data("request-dive-create"))
    let draft = try JSONValue.parse(KitFixture.data("request-dive-draft-write"))
    #expect(draft["values"]?.keys == create.keys)
    #expect(draft.keys == ["gear_set_uuid", "values"])
  }

  @Test func aDraftAlwaysSendsItsGearSetAndOnlyTheValuesItHolds() throws {
    var values = DiveDraftValues()
    values.startTime = DiveTimestamp(wireValue: "2026-09-14T14:30:00+03:00")
    let sent = try JSONValue.parse(
      APICoding.requestEncoder().encode(DiveDraftWrite(values: values)))
    #expect(
      sent
        == (try JSONValue.parse(
          Data(#"{"gear_set_uuid":null,"values":{"start_time":"2026-09-14T14:30:00+03:00"}}"#.utf8)))
    )
  }
}

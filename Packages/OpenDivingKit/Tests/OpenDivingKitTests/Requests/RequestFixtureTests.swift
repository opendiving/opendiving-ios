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

  @Test func aProposalOfTheDiversOwnSiteNamesNoMembers() throws {
    let proposal = try sendsItsFixture(
      DiveSiteProposalCreate.self, "request-dive-site-proposal-create")
    #expect(proposal.attestation == CommonsAttestations.newSite)
    #expect(proposal.members == nil)
  }

  @Test func aProposedChangeNamesWhatItWantsDifferent() throws {
    let proposal = try sendsItsFixture(
      DiveSiteProposalCreate.self, "request-dive-site-proposal-change")
    #expect(proposal.attestation == CommonsAttestations.change)
    #expect(proposal.members?.locationName == .null)
    #expect(proposal.members?.depthFrom == .value(5))
  }

  @Test func aReplaceNamesTheRecord() throws {
    let replace = try sendsItsFixture(DiveSiteReplace.self, "request-dive-site-replace")
    #expect(!replace.commonsSite.isLocal)
  }

  @Test func userUpdate() throws {
    let update = try sendsItsFixture(UserUpdate.self, "request-user-update")
    #expect(update.units == .imperial)
  }

  @Test func aUserUpdateSendsOnlyWhatItSets() throws {
    let sent = try JSONValue.parse(APICoding.requestEncoder().encode(UserUpdate(units: .metric)))
    #expect(sent == (try JSONValue.parse(Data(#"{"units":"metric"}"#.utf8))))
  }

  @Test func tagUpdate() throws {
    _ = try sendsItsFixture(TagUpdate.self, "request-tag-update")
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

  @Test func recordUpdates() throws {
    let person = try sendsItsFixture(PersonUpdate.self, "request-person-update")
    #expect(person.email == .null)
    let course = try sendsItsFixture(CourseUpdate.self, "request-course-update")
    #expect(course.contact == .null)
    #expect(course.people?.first?.role == "instructor")
    let contact = try sendsItsFixture(ContactUpdate.self, "request-contact-update")
    #expect(contact.latitude == .null)
    let gear = try sendsItsFixture(GearItemUpdate.self, "request-gear-item-update")
    #expect(gear.isArchived == true)
    #expect(gear.brand == .null)
  }

  @Test func serviceSchedulesAndRecords() throws {
    let schedule = try sendsItsFixture(
      GearServiceScheduleCreate.self, "request-gear-service-schedule-create")
    #expect(!schedule.gearItem.isLocal)
    let scheduleUpdate = try sendsItsFixture(
      GearServiceScheduleUpdate.self, "request-gear-service-schedule-update")
    #expect(scheduleUpdate.intervalMonths == .null)
    #expect(scheduleUpdate.isActive == false)
    let record = try sendsItsFixture(
      GearServiceRecordCreate.self, "request-gear-service-record-create")
    #expect(record.schedule?.isLocal == false)
    let recordUpdate = try sendsItsFixture(
      GearServiceRecordUpdate.self, "request-gear-service-record-update")
    #expect(recordUpdate.contact == .null)
  }

  @Test func certifications() throws {
    let create = try sendsItsFixture(CertificationCreate.self, "request-certification-create")
    #expect(create.instructor?.isLocal == false)
    let update = try sendsItsFixture(CertificationUpdate.self, "request-certification-update")
    #expect(update.course == .null)
    #expect(update.contact != .absent)
  }

  @Test func aPauseAndAnArchiveSendOneMember() throws {
    func sent(_ body: some Encodable) throws -> JSONValue {
      try JSONValue.parse(APICoding.requestEncoder().encode(body))
    }
    #expect(
      try sent(GearServiceScheduleUpdate(active: false))
        == (try JSONValue.parse(Data(#"{"is_active":false}"#.utf8))))
    #expect(
      try sent(GearItemUpdate(archived: true))
        == (try JSONValue.parse(Data(#"{"is_archived":true}"#.utf8))))
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
    let apply = try sendsItsFixture(LogbookImportApply.self, "request-import-apply")
    #expect(apply.checkInDetails?.phone == .null)
    #expect(apply.portrait?.take == false)
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

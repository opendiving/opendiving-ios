import Foundation
import OpenDivingKit
import Testing

/// The sheet's rows against the web's `/checkin` and its certification dialog.
struct CheckinSheetContentTests {
  private static let today = CalendarDate(year: 2026, month: 10, day: 23)!

  private static func card(
    _ certification: CertificationRead, front: CheckinSheetFile? = nil
  ) -> CheckinSheetCard {
    CheckinSheetCard(
      certification: certification, courseName: "Solo Diver", diveCenterName: "Big Blue Tech",
      instructorName: "Ivy Instructor", front: front, back: nil)
  }

  private static func sheet(
    units: UnitSystem = .metric, lastDive: String? = "2026-10-02T14:19:52.810000+03:00",
    cards: [CheckinSheetCard] = []
  ) throws -> CheckinSheet {
    CheckinSheet(
      name: "Test Diver", units: units,
      details: try KitFixture.decode(CheckinDetailsRead.self, "checkin-details"),
      totalDives: 1532, maxDepth: 47.42,
      lastDiveStart: lastDive.flatMap(DiveTimestamp.init(wireValue:)), portrait: nil,
      cards: cards, updatedAt: Date(timeIntervalSince1970: 1_761_219_900))
  }

  private static func certification(_ edit: (inout [String: Any]) -> Void = { _ in }) throws
    -> CertificationRead
  {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("certification-front-only"))
      as! [String: Any]
    edit(&object)
    return try APICoding.decoder().decode(
      CertificationRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func theDiverAndTheirDetails() throws {
    let content = CheckinSheetContent(try Self.sheet(), today: Self.today)
    #expect(content.name == "Test Diver")
    #expect(
      content.about == [
        Figure(label: "Date of birth", value: "Apr 12, 1988"),
        Figure(label: "Phone", value: "+20 100 000 0000"),
        Figure(label: "Email", value: "desk@example.org"),
      ])
    #expect(
      content.insurance == [
        [
          Figure(label: "Provider", value: "DAN Europe"),
          Figure(label: "Policy number", value: "DE-0000000"),
          Figure(label: "Expires", value: "Jun 30, 2027"),
        ],
        [Figure(label: "Provider", value: "Example Cover")],
      ])
    #expect(
      content.emergencyContacts == [
        [
          Figure(label: "Name", value: "Sam Example"),
          Figure(label: "Phone", value: "+49 170 0000000"),
          Figure(label: "Relationship", value: "Partner"),
        ],
        [Figure(label: "Name", value: "Alex Example")],
      ])
  }

  @Test func divingPrintsTheCountAsTheWebsStringDoesAndTheDiveOwnDay() throws {
    let content = CheckinSheetContent(
      try Self.sheet(lastDive: "2026-10-02T23:30:00-05:00"), today: Self.today)
    #expect(
      content.diving == [
        Figure(label: "Dives logged", value: "1532"),
        Figure(label: "Max depth", value: "47.42 m"),
        Figure(label: "Last dive", value: "Oct 2, 2026"),
      ])
  }

  @Test func divingInTheAccountsUnitsAndWithoutADive() throws {
    let content = CheckinSheetContent(
      try Self.sheet(units: .imperial, lastDive: nil), today: Self.today)
    #expect(content.diving.map(\.label) == ["Dives logged", "Max depth"])
    #expect(content.diving[1].value == UnitFormat.depth(47.42, .imperial))
    #expect(content.diving[1].value?.hasSuffix(" ft") == true)
  }

  @Test func lastUpdatedPrintsInTheGivenZone() throws {
    let utc = try #require(TimeZone(identifier: "UTC"))
    let content = CheckinSheetContent(try Self.sheet(), today: Self.today, timeZone: utc)
    #expect(content.lastUpdated == "Last updated Oct 23, 2025, 11:45")
  }

  @Test func aCardReadsLikeTheWebsDialog() throws {
    let front = CheckinSheetFile(
      name: "f", version: "f", etag: nil, contentType: "application/pdf")
    let content = CheckinCardContent(
      Self.card(try Self.certification(), front: front), today: Self.today)
    #expect(content.name == "Solo Diver")
    #expect(content.agency == "SDI")
    #expect(content.expiry == nil)
    #expect(
      content.rows == [
        Figure(label: "Certification number", value: "0000000"),
        Figure(label: "Course", value: "Solo Diver"),
        Figure(label: "Certified on", value: "Sep 25, 2025"),
        Figure(label: "Dive center", value: "Big Blue Tech"),
        Figure(label: "Instructor", value: "Ivy Instructor"),
        Figure(label: "Instructor number", value: "00000"),
      ])
    #expect(content.notes == nil)
    #expect(content.sides.map(\.label) == ["Front", "Back"])
    #expect(content.sides.map(\.missingText) == ["No front image", "No back image"])
    #expect(content.sides[0].file?.isPDF == true)
    #expect(content.sides[1].file == nil)
  }

  @Test func anOtherAgencyAndNotes() throws {
    let certification = try Self.certification {
      $0["agency"] = "other"
      $0["agency_other"] = "Reef Club"
      $0["notes"] = "Laminated"
      $0["certification_number"] = ""
    }
    let content = CheckinCardContent(Self.card(certification), today: Self.today)
    #expect(content.agency == "Reef Club")
    #expect(content.notes == "Laminated")
    #expect(!content.rows.map(\.label).contains("Certification number"))
  }

  @Test(arguments: [
    ("2026-10-23", CertificationExpiry.expiringSoon),
    ("2027-01-21", .expiringSoon),
    ("2026-10-22", .expired),
  ])
  func expiryAgainstToday(expiresOn: String, expected: CertificationExpiry) {
    #expect(
      CertificationExpiry(expiresOn: CalendarDate(iso8601: expiresOn), today: Self.today)
        == expected)
  }

  @Test func ninetyOneDaysOutOrNoExpiryIsNotFlagged() {
    #expect(
      CertificationExpiry(expiresOn: CalendarDate(iso8601: "2027-01-22"), today: Self.today)
        == nil)
    #expect(CertificationExpiry(expiresOn: nil, today: Self.today) == nil)
    #expect(CertificationExpiry.expired.label == "Expired")
    #expect(CertificationExpiry.expiringSoon.label == "Expiring soon")
  }
}

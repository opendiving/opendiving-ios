import Foundation
import Testing

@testable import OpenDivingKit

/// A course's *Add dives* and *Add certifications*: each row names its record, the course's own
/// are not offered, and each one picked is queued as its own move onto the course.
@MainActor
struct CourseAttachTests {
  private static let course = UUID(uuidString: "01a0a5da-6c85-770b-a009-8c7b4044c060")!
  private static let other = UUID(uuidString: "01a0a5da-6c85-770b-a009-8c7b4044c061")!

  private func dives() throws -> [DiveListItem] {
    try APICoding.decoder().decode(
      PaginatedListResponse<DiveListItem>.self, from: KitFixture.data("dives-page")
    ).data
  }

  /// `certification-front-only.json` with `changes` laid over it.
  private func certification(_ changes: [String: Any] = [:]) throws -> CertificationRead {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("certification-front-only"))
      as! [String: Any]
    for (key, value) in changes { object[key] = value }
    let data = try JSONSerialization.data(withJSONObject: object)
    return try APICoding.decoder().decode(CertificationRead.self, from: data)
  }

  @Test func aDivesRowSaysItsNumberItsDayItsTimeAndItsDepth() throws {
    let row = CourseAttach.row(try #require(try dives().first), units: .metric)
    #expect(row.title == "Dive #532")
    #expect(row.detail == "Oct 2, 2026, 14:19 · 54min · 23 m")
  }

  @Test func aCertificationsRowSaysItsAgencyAndItsDay() throws {
    #expect(
      CourseAttach.row(try certification())
        == CourseAttach.Row(title: "Solo Diver", detail: "SDI · Sep 25, 2025"))
    #expect(CourseAttach.row(try certification(["certified_on": NSNull()])).detail == "SDI")
  }

  @Test func theButtonCountsThePicks() {
    #expect(
      [0, 1, 3].map { CourseAttach.addLabel($0, one: "dive", many: "dives") } == [
        "Add dives", "Add 1 dive", "Add 3 dives",
      ])
  }

  @Test func whatIsOnTheCourseIsNotOffered() throws {
    let onIt = try certification()
    let elsewhere = try certification([
      "uuid": "01a0b07a-206e-76bd-bc56-e9646791ba21", "course_uuid": APIClient.wire(Self.other),
    ])
    let none = try certification([
      "uuid": "01a0b07a-206e-76bd-bc56-e9646791ba22", "course_uuid": NSNull(),
    ])
    #expect(
      CourseAttach.offered([onIt, elsewhere, none], course: Self.course).map(\.uuid)
        == [elsewhere.uuid, none.uuid])
    let dives = try dives()
    #expect(CourseAttach.offered(dives, course: Self.course).count == dives.count)
  }

  @Test func eachPickIsQueuedAsItsOwnMoveOntoTheCourse() async throws {
    let world = try OutboxWorld()
    world.offline()
    try await world.load()
    let outbox = world.outbox()
    let first = UUID()
    let second = UUID()
    #expect(CourseAttach.attach(dives: [first, second], to: Self.course, in: outbox) == nil)
    #expect(CourseAttach.attach(certifications: [first], to: Self.course, in: outbox) == nil)

    var dive = DiveUpdate()
    dive.course = .value(.server(Self.course))
    var card = CertificationUpdate()
    card.course = .value(.server(Self.course))
    #expect(
      outbox.items.map(\.operation) == [
        .updateDive(.server(first), dive), .updateDive(.server(second), dive),
        .updateCertification(.server(first), card),
      ])
  }
}

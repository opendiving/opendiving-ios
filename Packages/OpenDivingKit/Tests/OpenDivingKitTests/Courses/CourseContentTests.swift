import Foundation
import Testing

@testable import OpenDivingKit

/// A course's card, head, certifications and information card say what the web's say.
struct CourseContentTests {
  /// `course.json` with `changes` laid over it.
  private func course(_ changes: [String: Any] = [:]) throws -> CourseRead {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("course")) as! [String: Any]
    for (key, value) in changes { object[key] = value }
    let data = try JSONSerialization.data(withJSONObject: object)
    return try APICoding.decoder().decode(CourseRead.self, from: data)
  }

  private func certification(_ changes: [String: Any] = [:]) throws -> CertificationRead {
    var object =
      try JSONSerialization.jsonObject(with: KitFixture.data("certification-front-only"))
      as! [String: Any]
    for (key, value) in changes { object[key] = value }
    let data = try JSONSerialization.data(withJSONObject: object)
    return try APICoding.decoder().decode(CertificationRead.self, from: data)
  }

  @Test func theCardNamesTheStatusTheAgencyAndTheDates() throws {
    let card = PlainCardContent.course(try course())
    #expect(card.title == "Solo Diver")
    #expect(card.badges == [Badge("Completed", style: .primary)])
    #expect(card.facts.map(\.text) == ["SDI", "Sep 24 - Sep 25, 2025"])
    #expect(card.figures.isEmpty)
  }

  @Test func theCardLeavesOutWhatTheCourseLacks() throws {
    let card = PlainCardContent.course(
      try course(["agency": NSNull(), "start_date": NSNull(), "end_date": NSNull()]))
    #expect(card.facts.isEmpty)
    let other = PlainCardContent.course(
      try course(["agency": "other", "agency_other": "Cave Federation", "end_date": NSNull()]))
    #expect(other.facts.map(\.text) == ["Cave Federation", "Sep 24, 2025"])
  }

  @Test func eachStatusWearsTheWebsVariant() {
    let styles = [
      "completed", "incomplete", "provisional", "not_passed", "planned", "in_progress",
      "deferred",
    ].map { CoursePageContent.statusBadge($0) }
    #expect(
      styles == [
        Badge("Completed", style: .primary), Badge("Incomplete", style: .warning),
        Badge("Provisional", style: .warning), Badge("Not passed", style: .destructive),
        Badge("Planned", style: .outline), Badge("In progress", style: .outline),
        Badge("Deferred", style: .outline),
      ])
  }

  @Test func theHeadSaysTheAgencyTheDatesAndTheStatus() throws {
    let hero = CoursePageContent.hero(try course())
    #expect(hero.title == "Solo Diver")
    #expect(hero.facts.map(\.text) == ["SDI", "Sep 24 - Sep 25, 2025", "Completed"])
    #expect(hero.figures.isEmpty)
    #expect(hero.points.isEmpty)
  }

  @Test func aCourseWithNoAgencyShowsCertificationsOnlyOnceItHasOne() throws {
    let card = try certification()
    #expect(CoursePageContent.showsCertifications(try course(), certifications: []))
    let instructorsOwn = try course(["agency": NSNull()])
    #expect(!CoursePageContent.showsCertifications(instructorsOwn, certifications: []))
    #expect(CoursePageContent.showsCertifications(instructorsOwn, certifications: [card]))
  }

  @Test func aCertificationsRowSaysItsAgencyAndDay() throws {
    #expect(CoursePageContent.certificationLine(try certification()) == "SDI · Sep 25, 2025")
    #expect(
      CoursePageContent.certificationLine(try certification(["certified_on": NSNull()]))
        == "SDI")
  }

  @Test func theInformationNamesWhatThePhoneHoldsAndLeavesOutTheRest() throws {
    let instructor = UUID(uuidString: "01a0e2ed-1be6-72f8-8057-0b0caa945758")!
    let student = UUID(uuidString: "01a0e2ed-1be6-72f8-8057-0b0caa945759")!
    let centre = UUID(uuidString: "01a0d9e9-bdd0-793a-829f-5dc90613f84f")!
    let read = try course([
      "people": [
        ["person_uuid": instructor.uuidString.lowercased(), "role": "instructor"],
        ["person_uuid": student.uuidString.lowercased(), "role": "student"],
      ],
      "notes": "Line drills.",
    ])

    let unknown = CoursePageContent.information(
      read, people: [:], personLookups: [], contactLookups: [])
    #expect(unknown.diveCenter == nil)
    #expect(unknown.instructor == nil)
    #expect(unknown.people.isEmpty)
    #expect(unknown.instructorNumber == "00000")
    #expect(unknown.notes == "Line drills.")

    let person = try KitFixture.decode(PersonRead.self, "person")
    let known = CoursePageContent.information(
      read, people: [instructor: person],
      personLookups: [PersonLookupItem(ref: .server(student), name: "Sam Lee")],
      contactLookups: [ContactLookupItem(ref: .server(centre), name: "Example Dive Centre")])
    #expect(known.diveCenter == "Example Dive Centre")
    #expect(known.instructor == PersonRowContent(uuid: instructor, name: "Dana Reyes"))
    // The people under the instructor come from the session's table alone, as a dive's do.
    #expect(known.people.isEmpty)

    let both = CoursePageContent.information(
      read, people: [instructor: person, student: person], personLookups: [],
      contactLookups: [])
    #expect(both.people.map(\.role) == ["Student"])
  }

  @Test func blankFieldsHaveNoRow() throws {
    let info = CoursePageContent.information(
      try course(["instructor_number": "", "notes": ""]), people: [:], personLookups: [],
      contactLookups: [])
    #expect(info.instructorNumber == nil)
    #expect(info.notes == nil)
  }
}

import Foundation
import Testing

@testable import OpenDivingKit

/// The certification form's rules, its bodies, and the course's one-time fill, against the web's
/// dialog and its tests.
struct CertificationFormValuesTests {
  private static let shop = RecordRef.server(UUID())
  private static let otherShop = RecordRef.server(UUID())
  private static let kim = RecordRef.server(UUID())
  private static let sam = RecordRef.server(UUID())
  private static let course = RecordRef.server(UUID())

  /// The web test's `COURSE`: TDI, Blue Ocean, Kim with number 123.
  private static let tdiCourse = CertificationCourseFill(
    name: "Advanced Nitrox", agency: "tdi", contact: shop, instructor: kim,
    instructorNumber: "123")
  /// Its `OTHER_COURSE`: SSI, Red Sea, Sam and no number.
  private static let ssiCourse = CertificationCourseFill(
    name: "Rescue", agency: "ssi", contact: otherShop, instructor: sam, instructorNumber: "")

  @Test func aNewCardOpensOnPADIWithNothingElse() {
    let values = CertificationFormValues()
    #expect(values.agency == "padi")
    #expect(values.name.isEmpty && values.course == nil && values.contact == nil)
  }

  @Test func theRulesAreTheWebSchemas() {
    var values = CertificationFormValues(name: "  ")
    #expect(values.issues.map(\.message) == ["Certification name is required"])

    values = CertificationFormValues(
      name: "Rescue", agency: "other", certifiedOn: CalendarDate(year: 2026, month: 3, day: 2),
      expiresOn: CalendarDate(year: 2026, month: 3, day: 1))
    #expect(
      values.issues.map(\.field) == ["agency_other", "expires_on"]
        && values.issues.map(\.message) == [
          "Tell us which agency issued this",
          "Expiry date cannot be before the certification date",
        ])

    values = CertificationFormValues(
      name: "Rescue", certificationNumber: String(repeating: "1", count: 65))
    #expect(
      values.issues.map(\.message) == ["Certification number cannot exceed 64 characters"])
  }

  @Test func theCreateLeavesBlanksOutAndNamesAnAgencyOnlyForOther() throws {
    let body = try CertificationFormValues(
      name: " Rescue Diver ", agency: "padi", agencyOther: "Left over", certificationNumber: "",
      instructorNumber: "", notes: ""
    ).toCreate()
    #expect(body.name == "Rescue Diver")
    #expect(body.agencyOther == nil)
    #expect(body.certificationNumber == nil && body.instructorNumber == nil)

    let other = try CertificationFormValues(
      name: "Cave", agency: "other", agencyOther: "SwedTech Diving"
    ).toCreate()
    #expect(other.agencyOther == "SwedTech Diving")
  }

  @Test func anEditSendsOnlyWhatChangedAndClearsWhatWasEmptied() throws {
    let stored = try KitFixture.decode(CertificationRead.self, "certification-front-only")
    let baseline = CertificationFormValues(editing: stored)
    #expect(try baseline.diff(from: baseline).isEmpty)

    var edited = baseline
    edited.name = "Solo Diver Plus"
    edited.certificationNumber = ""
    edited.instructor = nil
    let update = try edited.diff(from: baseline)
    var expected = CertificationUpdate()
    expected.name = "Solo Diver Plus"
    expected.certificationNumber = .null
    expected.instructor = .null
    #expect(update == expected)
    #expect(baseline.applying(update).toCreateOrNil == edited.toCreateOrNil)
  }

  @Test func leavingOtherClearsTheAgencysName() throws {
    let baseline = CertificationFormValues(name: "Cave", agency: "other", agencyOther: "Swed")
    var edited = baseline
    edited.agency = "gue"
    let update = try edited.diff(from: baseline)
    #expect(update.agency == "gue" && update.agencyOther == .null)
  }

  @Test func aRefusedCreateReopensAsItWasSent() throws {
    let values = CertificationFormValues(
      course: Self.course, name: "Rescue", agency: "naui", certificationNumber: "N-1",
      contact: Self.shop, instructor: Self.kim, notes: "Night")
    let reopened = try #require(CertificationFormValues(reopening: try values.operation()))
    #expect(reopened.toCreateOrNil == values.toCreateOrNil)
    #expect(CertificationFormValues(reopening: .deleteCertification(Self.course)) == nil)
  }

  // MARK: - The course's fill

  @Test func aCourseFillsWhatTheFormItselfPutThereTheDefaultAgencyIncluded() {
    var values = CertificationFormValues()
    values.fill(from: Self.tdiCourse)
    #expect(values.name == "Advanced Nitrox" && values.agency == "tdi")
    #expect(values.contact == Self.shop && values.instructor == Self.kim)
    #expect(values.instructorNumber == "123")
    #expect(values.notes.isEmpty)
  }

  @Test func aLevelTheDiverTypedIsKept() {
    var values = CertificationFormValues()
    values.name = "Advanced Nitrox Diver"
    values.fill(from: Self.tdiCourse)
    #expect(values.name == "Advanced Nitrox Diver")
    #expect(values.contact == Self.shop)
  }

  @Test func aSecondCourseReplacesTheFirstsFillAndEmptiesWhatItLacks() {
    var values = CertificationFormValues()
    values.fill(from: Self.tdiCourse)
    values.fill(from: Self.ssiCourse)
    #expect(values.instructor == Self.sam && values.instructorNumber.isEmpty)
    #expect(values.agency == "ssi" && values.contact == Self.otherShop)
  }

  @Test func theDiversDiveCenterSurvivesTwoCourses() {
    var values = CertificationFormValues()
    values.fill(from: Self.tdiCourse)
    let own = RecordRef.server(UUID())
    values.contact = own
    values.fill(from: Self.ssiCourse)
    values.fill(from: Self.tdiCourse)
    #expect(values.contact == own)
  }

  @Test func aCourseNamingNoAgencyLeavesThePair() {
    var values = CertificationFormValues()
    values.agency = "other"
    values.agencyOther = "Swed"
    values.fill(from: CertificationCourseFill(name: "Sidemount, with Kim", instructor: Self.kim))
    #expect(values.agency == "other" && values.agencyOther == "Swed")
    #expect(values.instructor == Self.kim)
  }

  @Test func aPickersRowLeavesTheInstructorNumberAlone() {
    var values = CertificationFormValues()
    values.fill(from: Self.tdiCourse)
    let row = CourseLookupItem(
      ref: Self.course, name: "Rescue",
      people: [PersonReference(person: Self.sam, role: "instructor")])
    values.fill(from: CertificationCourseFill(row))
    #expect(values.instructor == Self.sam && values.instructorNumber == "123")
  }

  @Test func aCardForACourseOpensFilledAndTreatsTheFillAsItsOwn() throws {
    let course = try KitFixture.decode(CourseRead.self, "course")
    var values = CertificationFormValues(
      for: CertificationCourseFill(course), ref: .server(course.uuid))
    #expect(values.course == .server(course.uuid))
    #expect(values.name == "Solo Diver" && values.agency == "sdi")
    #expect(values.instructor == course.people.first?.person)
    values.fill(from: Self.ssiCourse)
    #expect(values.name == "Rescue" && values.agency == "ssi")
  }

  @Test func aCourseWithNoAgencyOpensOnTheDefault() {
    let values = CertificationFormValues(
      for: CertificationCourseFill(name: "Sidemount"), ref: Self.course)
    #expect(values.agency == "padi" && values.agencyOther.isEmpty)
  }

  @Test func movingTheCertifiedDatePastTheExpiryEmptiesIt() {
    var values = CertificationFormValues(expiresOn: CalendarDate(year: 2026, month: 1, day: 1))
    values.pickCertifiedOn(CalendarDate(year: 2026, month: 2, day: 1))
    #expect(values.expiresOn == nil)
  }
}

extension CertificationFormValues {
  fileprivate var toCreateOrNil: CertificationCreate? { try? toCreate() }
}

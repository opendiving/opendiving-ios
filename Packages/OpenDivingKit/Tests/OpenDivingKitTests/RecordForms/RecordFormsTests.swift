import Foundation
import OpenDivingKit
import Testing

/// The record dialogs' rules and bodies against the web's: rows from `src/lib/validations/*.test.ts`
/// at `opendiving-web` `d5b2d545`, each with the file and line, and the sentences their schemas
/// give at the same sha.
struct RecordFormsTests {
  private func fields(_ issues: [FormIssue]) -> [String] {
    issues.map {
      [$0.field, $0.index.map(String.init), $0.member].compactMap { $0 }.joined(separator: ".")
    }
  }

  // MARK: Dive site

  @Test func aSiteIsANameAndWhatTheDiverAdds() throws {
    #expect(DiveSiteFormValues(name: "Blue Hole").issues.isEmpty)  // dive-site.test.ts:17
    #expect(
      DiveSiteFormValues(name: "  ").issues == [
        FormIssue(field: "name", message: "Dive site name is required")
      ])
    #expect(
      DiveSiteFormValues(name: String(repeating: "x", count: 256)).issues
        == [FormIssue(field: "name", message: "Dive site name cannot exceed 255 characters")])
    #expect(
      fields(DiveSiteFormValues(name: "x", notes: String(repeating: "x", count: 100_001)).issues)
        == ["notes"])
  }

  /// dive-site.test.ts:60-117, and the comma the phone's keypad types.
  @Test func thePin() {
    func issues(_ latitude: String, _ longitude: String) -> [FormIssue] {
      DiveSiteFormValues(name: "x", latitude: latitude, longitude: longitude).issues
    }
    #expect(issues("27.8506", "34.3136").isEmpty)
    #expect(issues("-8", "115").isEmpty)
    #expect(issues("", "").isEmpty)
    #expect(issues("27,8506", "34,3136").isEmpty)
    #expect(
      issues("27.8506", "") == [
        FormIssue(field: "longitude", message: "Longitude is required when latitude is given")
      ])
    #expect(
      issues("", "34.3136") == [
        FormIssue(field: "latitude", message: "Latitude is required when longitude is given")
      ])
    #expect(
      issues("91", "0") == [
        FormIssue(field: "latitude", message: "Latitude must be between -90 and 90")
      ])
    #expect(
      issues("0", "181") == [
        FormIssue(field: "longitude", message: "Longitude must be between -180 and 180")
      ])
    #expect(
      issues("abc", "0") == [
        FormIssue(field: "latitude", message: "Latitude must be a decimal number, e.g. 27.8506")
      ])
    #expect(issues("1.234,5", "0").map(\.field) == ["latitude"])
  }

  /// dive-site.test.ts:292-330.
  @Test func depthsAndAltitude() {
    #expect(DiveSiteFormValues(name: "x", depthFrom: 5, depthTo: 30).issues.isEmpty)
    #expect(DiveSiteFormValues(name: "x", depthFrom: 12, depthTo: 12).issues.isEmpty)
    #expect(
      DiveSiteFormValues(name: "x", depthFrom: 30, depthTo: 5).issues
        == [FormIssue(field: "depth_to", message: "Depth to cannot be shallower than depth from")])
    #expect(
      DiveSiteFormValues(name: "x", depthFrom: -1).issues
        == [FormIssue(field: "depth_from", message: "Depth from cannot be negative")])
    #expect(DiveSiteFormValues(name: "x", altitude: -430).issues.isEmpty)
    #expect(fields(DiveSiteFormValues(name: "x", altitude: 6501).issues) == ["altitude"])
  }

  /// dive-site.test.ts:401-408 and the dialog's create.
  @Test func aSiteCreate() throws {
    let create = try DiveSiteFormValues(
      name: " Blue Hole ", otherNames: [" El Bells ", "", "   "],
      location: LocationWrite(name: " Dahab ", latitude: 28.5, longitude: 34.5),
      latitude: "28,57", longitude: "34.54", entryTypes: ["shore"]
    ).toCreate()
    #expect(create.name == "Blue Hole")
    #expect(create.otherNames == ["El Bells"])
    #expect(create.location?.name == "Dahab")
    #expect(create.latitude == 28.57)
    #expect(create.longitude == 34.54)
    #expect(create.entryTypes == ["shore"])
    #expect(throws: FormInvalid.self) { try DiveSiteFormValues().toCreate() }
  }

  // MARK: Person

  @Test func aPerson() throws {
    #expect(
      PersonFormValues(name: "").issues == [FormIssue(field: "name", message: "Name is required")])
    #expect(
      PersonFormValues(name: "Alex", email: "not-an-email").issues
        == [FormIssue(field: "email", message: "Please enter a valid email address")])
    #expect(
      PersonFormValues(name: "Alex", username: "@" + String(repeating: "a", count: 21)).issues
        == [FormIssue(field: "username", message: "Username cannot exceed 20 characters")])
    #expect(
      PersonFormValues(name: "Alex", phone: String(repeating: "1", count: 33)).issues
        == [FormIssue(field: "phone", message: "Phone cannot exceed 32 characters")])
    let create = try PersonFormValues(
      name: " Alex ", username: " @alexm ", email: " alex@example.com ", phone: "  "
    ).toCreate()
    #expect(create == PersonCreate(name: "Alex", email: "alex@example.com", username: "alexm"))
  }

  @Test(arguments: [
    ("info@blueocean.com", true), ("a.b+c@dive.example.org", true), ("o'neil@x.co", true),
    ("not-an-email", false), (".a@x.com", false), ("a..b@x.com", false), ("a.@x.com", false),
    ("a@x", false), ("a@x.c", false), ("a@-x.com", false), ("a@x..com", false),
    ("a@b@c.com", false),
  ])
  func emailAddresses(_ text: String, _ valid: Bool) {
    #expect(PersonFormValues(name: "x", email: text).issues.isEmpty == valid)
  }

  // MARK: Trip

  /// trip.test.ts:12-186 and name.test.ts:18-25.
  @Test func aTrip() throws {
    #expect(TripFormValues(name: "Red Sea").issues.isEmpty)
    #expect(
      TripFormValues(name: "   ").issues == [
        FormIssue(field: "name", message: "Trip name is required")
      ])
    let day = { (text: String) in CalendarDate(iso8601: text) }
    let reversed = TripFormValues(
      name: "x",
      parts: [
        TripPartFormValues(startDate: day("2026-10-01"), endDate: day("2026-10-05")),
        TripPartFormValues(startDate: day("2026-10-05"), endDate: day("2026-10-04")),
      ])
    #expect(
      reversed.issues == [
        FormIssue(
          field: "parts", index: 1, member: "end_date",
          message: "End date must be on or after start date")
      ])
    #expect(
      fields(
        TripFormValues(name: "x", parts: [TripPartFormValues(location: LocationWrite(name: ""))])
          .issues) == ["parts.0.location"])
    #expect(
      TripFormValues(name: "x", parts: Array(repeating: TripPartFormValues(), count: 21)).issues
        == [FormIssue(field: "parts", message: "A trip cannot have more than 20 parts")])
    // trip.test.ts:203-212: a part holding nothing is dropped, its neighbours kept in order.
    let create = try TripFormValues(
      name: " Red Sea ",
      parts: [
        TripPartFormValues(location: LocationWrite(name: "Dahab")), TripPartFormValues(),
        TripPartFormValues(startDate: day("2026-10-01")),
      ]
    ).toCreate()
    #expect(create.name == "Red Sea")
    #expect(create.parts.map(\.location?.name) == ["Dahab", nil])
    #expect(TripFormValues().parts.count == 1)
    #expect(try TripFormValues(name: "x").toCreate().parts.isEmpty)
  }

  @Test func aTripsAccommodationAndPeopleAreRewritten() {
    let hotel = RecordRef.local(UUID())
    let buddy = RecordRef.local(UUID())
    var trip = TripFormValues(
      name: "x", parts: [TripPartFormValues(accommodation: hotel)],
      people: [PersonReference(person: buddy, role: "buddy")])
    let named = RecordRef.server(UUID())
    trip.rewriteRefs { $0 == hotel ? named : nil }
    #expect(trip.parts[0].accommodation == named)
    #expect(trip.people.isEmpty)
  }

  // MARK: Course

  /// course.test.ts:16-160.
  @Test func aCourse() throws {
    #expect(CourseFormValues(name: "Open Water").issues.isEmpty)
    #expect(
      CourseFormValues().issues == [FormIssue(field: "name", message: "Course name is required")])
    #expect(
      CourseFormValues(name: "x", agency: "other", agencyOther: "  ").issues
        == [FormIssue(field: "agency_other", message: "Tell us which agency ran this course")])
    #expect(CourseFormValues(name: "x", agency: "other", agencyOther: "Local club").issues.isEmpty)
    #expect(CourseFormValues(name: "x", agency: "padi", agencyOther: "stale").issues.isEmpty)
    #expect(
      CourseFormValues(
        name: "x", startDate: CalendarDate(iso8601: "2026-10-05"),
        endDate: CalendarDate(iso8601: "2026-10-04")
      ).issues == [FormIssue(field: "end_date", message: "End date must be on or after start date")]
    )
    #expect(
      CourseFormValues(name: "x", instructorNumber: String(repeating: "1", count: 65)).issues
        == [
          FormIssue(
            field: "instructor_number", message: "Instructor number cannot exceed 64 characters")
        ])
    #expect(CourseFormValues().status == "completed")
  }

  /// `joinCourseInstructor`: the instructor first, as the instructor, and nobody twice.
  @Test func aCoursesInstructorLeadsItsPeople() throws {
    let instructor = RecordRef.server(UUID())
    let student = RecordRef.server(UUID())
    var course = CourseFormValues(
      name: " Nitrox ", agency: "padi", agencyOther: "stale",
      people: [
        PersonReference(person: student, role: "student"), PersonReference(person: instructor),
      ])
    course.pickInstructor(instructor)
    #expect(course.people == [PersonReference(person: student, role: "student")])
    let create = try course.toCreate()
    #expect(create.name == "Nitrox")
    #expect(create.agencyOther == nil)
    #expect(
      create.people == [
        PersonReference(person: instructor, role: "instructor"),
        PersonReference(person: student, role: "student"),
      ])
    #expect(create.instructorNumber == nil)
  }

  // MARK: Contact

  /// contact.test.ts:29-118.
  @Test func aContact() throws {
    let valid = ContactFormValues(name: "Blue Ocean")
    #expect(valid.issues.isEmpty)
    var website = valid
    website.website = "blueocean.com"
    #expect(website.issues.isEmpty)
    #expect(try website.toCreate().website == "https://blueocean.com")
    for refused in [
      "ftp://blueocean.com", "not a url", "blueocean.com/" + String(repeating: "a", count: 491),
    ] {
      website.website = refused
      #expect(
        website.issues == [
          FormIssue(field: "website", message: "Use a web address, e.g. blueocean.com")
        ],
        "\(refused)")
    }
    website.website = "blueocean.com/" + String(repeating: "a", count: 490)
    #expect(website.issues.isEmpty)

    var address = valid
    address.city = "Dahab"
    #expect(
      address.issues == [
        FormIssue(field: "address", member: "country", message: "An address needs its country")
      ])
    address.country = " "
    #expect(fields(address.issues) == ["address.country"])
    address.country = "Egypt"
    #expect(address.issues.isEmpty)
    address.postcode = String(repeating: "1", count: 33)
    #expect(
      address.issues == [
        FormIssue(
          field: "address", member: "postcode", message: "Postcode cannot exceed 32 characters")
      ])

    var email = valid
    email.email = "not-an-email"
    #expect(fields(email.issues) == ["email"])
  }

  /// contact.test.ts:120-140, and the dive-centre preset the dive form's picker opens with.
  @Test func aContactCreate() throws {
    let create = try ContactFormValues(
      name: " Blue Ocean ", roles: ContactFormValues.diveCenterRoles, phone: " ", email: "",
      street: " 1 Reef Road ", city: "Dahab", country: " Egypt ", latitude: "28,5",
      longitude: "34.5"
    ).toCreate()
    #expect(create.name == "Blue Ocean")
    #expect(create.roles == ["dive_center"])
    #expect(create.phone == nil)
    #expect(create.email == nil)
    #expect(
      create.address == ContactAddressWrite(street: "1 Reef Road", city: "Dahab", country: "Egypt"))
    #expect(create.latitude == 28.5)
    #expect(try ContactFormValues(name: "x").toCreate().address == nil)
  }

  // MARK: Gear

  /// gear.test.ts:5-160.
  @Test func aGearItem() throws {
    #expect(GearItemFormValues(name: "Wing 17L").issues.isEmpty)
    #expect(
      GearItemFormValues(name: "").issues == [
        FormIssue(field: "name", message: "Gear name is required")
      ])
    #expect(
      GearItemFormValues(name: "x", brand: String(repeating: "b", count: 256)).issues
        == [FormIssue(field: "brand", message: "Brand cannot exceed 255 characters")])
    #expect(fields(GearItemFormValues(name: "x", type: "cylinder", volume: 0).issues) == ["volume"])
    #expect(
      fields(GearItemFormValues(name: "x", type: "cylinder", workingPressure: 0).issues) == [
        "working_pressure"
      ])
    #expect(
      GearItemFormValues(name: "x", type: "cylinder", workingPressure: 351).issues == [
        FormIssue(
          field: "working_pressure",
          message:
            "Working pressure must be at most 350 bar (5,076 psi) — check the units on that reading."
        )
      ])
    let cylinder = try GearItemFormValues(
      name: " AL80 ", brand: " ", type: "cylinder", volume: 11.1, workingPressure: 207,
      material: "aluminium"
    ).toCreate()
    #expect(
      cylinder
        == GearItemCreate(
          name: "AL80", type: "cylinder", volume: 11.1, workingPressure: 207, material: "aluminium")
    )
    let fins = try GearItemFormValues(name: "Fins", type: "fins", volume: 11.1).toCreate()
    #expect(fins.volume == nil)
  }

  @Test func aGearSet() throws {
    let item = RecordRef.server(UUID())
    #expect(
      GearSetFormValues().issues == [FormIssue(field: "name", message: "Set name is required")])
    #expect(
      GearSetFormValues(name: "x", weight: -1).issues
        == [FormIssue(field: "weight", message: "Weight must be zero or positive")])
    let saving = GearSetFormValues(saving: DiveFormValues(weight: 4, gearItems: [item]))
    #expect(saving.items == [item])
    #expect(saving.weight == 4)
    var named = saving
    named.name = " Warm water "
    #expect(try named.toCreate() == GearSetCreate(name: "Warm water", weight: 4, gearItems: [item]))
    named.weight = nil
    #expect(
      try named.toUpdate() == GearSetUpdate(name: "Warm water", weight: .null, gearItems: [item]))
  }
}

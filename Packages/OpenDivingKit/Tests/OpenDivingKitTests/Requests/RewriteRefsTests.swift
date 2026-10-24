import Foundation
import OpenDivingKit
import Testing

/// Every request body rewrites the refs it holds: a local one replaced by the server's uuid
/// when its create lands, a server one dropped when it is released.
struct RewriteRefsTests {
  private let localSite = UUID()
  private let landedSite = UUID()
  private let releasedTrip = UUID()
  private let localPerson = UUID()
  private let landedPerson = UUID()
  private let keptGear = UUID()

  /// The local site and person land; the server trip is released; everything else stays.
  private func rewrite(_ ref: RecordRef) -> RecordRef? {
    switch ref {
    case .local(localSite): .server(landedSite)
    case .local(localPerson): .server(landedPerson)
    case .server(releasedTrip): nil
    default: ref
    }
  }

  @Test func aDiveCreate() throws {
    var dive = DiveCreate(
      diveNumber: 1, startTime: try #require(DiveTimestamp(wireValue: "2026-09-14T09:12:00Z")),
      submergedTime: 60, trip: .server(releasedTrip), course: .local(UUID()),
      mixtures: [DiveMixtureWrite(gearItem: .server(keptGear))],
      diveSites: [.local(localSite), .server(keptGear)],
      people: [PersonReference(person: .local(localPerson), role: "buddy")])
    let course = dive.course
    dive.rewriteRefs(rewrite)
    #expect(dive.trip == nil)
    #expect(dive.course == course)
    #expect(dive.diveSites == [.server(landedSite), .server(keptGear)])
    #expect(dive.mixtures.first?.gearItem == .server(keptGear))
    #expect(dive.people == [PersonReference(person: .server(landedPerson), role: "buddy")])
  }

  @Test func aDroppedSiteLeavesTheListAndADroppedPersonLeavesWithTheirRole() throws {
    var dive = DiveCreate(
      diveNumber: 1, startTime: try #require(DiveTimestamp(wireValue: "2026-09-14T09:12:00Z")),
      submergedTime: 60, diveSites: [.server(releasedTrip), .local(localSite)],
      people: [PersonReference(person: .server(releasedTrip), role: "guide")])
    dive.rewriteRefs(rewrite)
    #expect(dive.diveSites == [.server(landedSite)])
    #expect(dive.people.isEmpty)
  }

  @Test func aDiveUpdate() {
    var update = DiveUpdate()
    update.trip = .value(.server(releasedTrip))
    update.contact = .null
    update.diveSites = [.local(localSite)]
    update.people = [PersonReference(person: .local(localPerson))]
    update.rewriteRefs(rewrite)
    // A dropped trip is no longer sent at all, rather than detaching the dive's trip.
    #expect(update.trip == .absent)
    #expect(update.contact == .null)
    #expect(update.diveSites == [.server(landedSite)])
    #expect(update.people == [PersonReference(person: .server(landedPerson))])
    #expect(update.gearItems == nil)
  }

  @Test func aDiveDraft() {
    var values = DiveDraftValues()
    values.diveSites = [.local(localSite)]
    values.trip = .server(releasedTrip)
    values.mixtures = [DiveMixtureWrite(gearItem: .server(releasedTrip))]
    var draft = DiveDraftWrite(gearSet: .server(releasedTrip), values: values)
    draft.rewriteRefs(rewrite)
    #expect(draft.gearSet == nil)
    #expect(draft.values.diveSites == [.server(landedSite)])
    #expect(draft.values.trip == nil)
    #expect(draft.values.mixtures == [DiveMixtureWrite()])
    #expect(draft.values.people == nil)
  }

  @Test func aTripACourseAndAGearSet() {
    var trip = TripCreate(
      name: "Trip", parts: [TripPartWrite(accommodation: .server(releasedTrip))],
      people: [PersonReference(person: .local(localPerson))])
    trip.rewriteRefs(rewrite)
    #expect(trip.parts.first?.accommodation == nil)
    #expect(trip.people.first?.person == .server(landedPerson))

    var course = CourseCreate(
      name: "Course", contact: .server(releasedTrip),
      people: [PersonReference(person: .local(localPerson), role: "instructor")])
    course.rewriteRefs(rewrite)
    #expect(course.contact == nil)
    #expect(course.people == [PersonReference(person: .server(landedPerson), role: "instructor")])

    var set = GearSetCreate(name: "Set", gearItems: [.server(releasedTrip), .local(localSite)])
    set.rewriteRefs(rewrite)
    #expect(set.gearItems == [.server(landedSite)])

    var update = GearSetUpdate(gearItems: [.local(localSite)])
    update.rewriteRefs(rewrite)
    #expect(update.gearItems == [.server(landedSite)])
  }

  @Test func theRecordsThatNameNoOtherAreUnchanged() {
    var site = DiveSiteCreate(name: "Site")
    var person = PersonCreate(name: "Person")
    var contact = ContactCreate(name: "Contact")
    var item = GearItemCreate(name: "Item")
    site.rewriteRefs(rewrite)
    person.rewriteRefs(rewrite)
    contact.rewriteRefs(rewrite)
    item.rewriteRefs(rewrite)
    #expect(site == DiveSiteCreate(name: "Site"))
    #expect(person == PersonCreate(name: "Person"))
    #expect(contact == ContactCreate(name: "Contact"))
    #expect(item == GearItemCreate(name: "Item"))
  }

  @Test func aLookupRowTakesItsServerRefAndKeepsItsOwnWhenDropped() {
    var site = DiveSiteLookupItem(ref: .local(localSite), name: "New site")
    site.rewriteRefs(rewrite)
    #expect(site.ref == .server(landedSite))
    var trip = TripLookupItem(
      ref: .server(releasedTrip), name: "Trip",
      people: [PersonReference(person: .local(localPerson))])
    trip.rewriteRefs(rewrite)
    #expect(trip.ref == .server(releasedTrip))
    #expect(trip.people == [PersonReference(person: .server(landedPerson))])
  }
}

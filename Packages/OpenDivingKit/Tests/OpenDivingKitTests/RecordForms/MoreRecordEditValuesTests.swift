import Foundation
import Testing

@testable import OpenDivingKit

/// What an edit of a person, a course, a contact, a piece of gear or a gear set sends: what
/// differs from what the form opened on, in the shape the API takes it.
struct MoreRecordEditValuesTests {
  private func wire(_ value: some Encodable) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: APIClient.json(value))
    return try #require(object as? [String: Any])
  }

  @Test func eachFormOpenedAndSavedChangesNothing() throws {
    let person = PersonFormValues(editing: try KitFixture.decode(PersonRead.self, "person"))
    #expect(try person.diff(from: person).isEmpty)
    let course = CourseFormValues(editing: try KitFixture.decode(CourseRead.self, "course"))
    #expect(try course.diff(from: course).isEmpty)
    let contact = ContactFormValues(editing: try KitFixture.decode(ContactRead.self, "contact"))
    #expect(try contact.diff(from: contact).isEmpty)
    let gear = GearItemFormValues(editing: try KitFixture.decode(GearItemRead.self, "gear-item"))
    #expect(try gear.diff(from: gear).isEmpty)
    let set = GearSetFormValues(editing: try KitFixture.decode(GearSetRead.self, "gear-set"))
    #expect(try set.diff(from: set).isEmpty)
  }

  @Test func aPersonsEmailEmptiedIsCleared() throws {
    let before = PersonFormValues(editing: try KitFixture.decode(PersonRead.self, "person"))
    var after = before
    after.email = " "
    after.username = "@dana"
    #expect(try after.diff(from: before) == PersonUpdate(email: .null, username: .value("dana")))
    #expect(try wire(after.diff(from: before))["email"] is NSNull)
  }

  @Test func aCoursesInstructorOpensInItsFieldAndGoesBackFirst() throws {
    let read = try KitFixture.decode(CourseRead.self, "course")
    let before = CourseFormValues(editing: read)
    #expect(before.instructor == read.people.first?.person)
    #expect(before.people.isEmpty)
    var after = before
    let student = RecordRef.server(UUID())
    after.people = [PersonReference(person: student)]
    let update = try after.diff(from: before)
    #expect(update.people == [read.people[0], PersonReference(person: student)])
    #expect(before.applying(update) == after)
  }

  @Test func aCoursesCentreTakenOffIsCleared() throws {
    let before = CourseFormValues(editing: try KitFixture.decode(CourseRead.self, "course"))
    var after = before
    after.contact = nil
    var expected = CourseUpdate()
    expected.contact = .null
    #expect(try after.diff(from: before) == expected)
  }

  @Test func aContactsAddressGoesWholeAndItsPositionAsAPair() throws {
    let before = ContactFormValues(editing: try KitFixture.decode(ContactRead.self, "contact"))
    var after = before
    after.street = "1 Sairee Beach"
    after.latitude = "10.1"
    after.longitude = "99.8"
    let update = try after.diff(from: before)
    #expect(
      update.address
        == .value(
          ContactAddressWrite(street: "1 Sairee Beach", city: "Koh Tao", country: "Thailand")))
    #expect(update.latitude == .value(10.1))
    #expect(update.longitude == .value(99.8))
    #expect(before.applying(update) == after)

    var moved = after
    moved.longitude = "99.9"
    let pair = try moved.diff(from: after)
    #expect(pair.latitude == .value(10.1))
    #expect(pair.longitude == .value(99.9))
  }

  @Test func gearNoLongerACylinderLosesItsCylindersFacts() throws {
    let before = GearItemFormValues(
      editing: try KitFixture.decode(GearItemRead.self, "gear-item"))
    #expect(before.volume != nil)
    var after = before
    after.type = "regulator"
    let update = try after.diff(from: before)
    #expect(update.type == .value("regulator"))
    #expect(update.volume == .null)
    #expect(try wire(update)["volume"] is NSNull)
  }

  @Test func aGearSetSendsItsListWholeAndAClearedWeight() throws {
    let before = GearSetFormValues(editing: try KitFixture.decode(GearSetRead.self, "gear-set"))
    var after = before
    after.items = Array(before.items.reversed()) + [.server(UUID())]
    after.weight = nil
    let update = try after.diff(from: before)
    #expect(update.gearItems == after.items)
    #expect(update.weight == (before.weight == nil ? .absent : .null))
    #expect(before.applying(update) == after)
  }

  @Test func eachEditQueuesItsUpdateAndItsDelete() throws {
    let ref = RecordRef.server(UUID())
    let before = PersonFormValues(editing: try KitFixture.decode(PersonRead.self, "person"))
    var after = before
    after.notes = "Night dives"
    #expect(
      try after.update(of: ref, from: before)
        == .updatePerson(ref, PersonUpdate(notes: "Night dives")))
    #expect(try before.update(of: ref, from: before) == nil)
    #expect(PersonFormValues.delete(ref) == .deletePerson(ref))
    #expect(CourseFormValues.delete(ref) == .deleteCourse(ref))
    #expect(ContactFormValues.delete(ref) == .deleteContact(ref))
    #expect(GearItemFormValues.delete(ref) == .deleteGearItem(ref))
    #expect(GearSetFormValues.delete(ref) == .deleteGearSet(ref))
  }

  @Test func aGearSetCreateReopensOverItsBody() throws {
    let values = GearSetFormValues(name: "Warm", weight: 4, items: [.server(UUID())])
    let reopened = GearSetFormValues(reopening: try values.operation())
    #expect(reopened == values)
  }
}

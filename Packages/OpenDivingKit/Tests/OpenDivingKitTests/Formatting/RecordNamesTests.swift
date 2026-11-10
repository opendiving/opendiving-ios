import Foundation
import Testing

@testable import OpenDivingKit

/// A name the phone holds only as a uuid, from what it holds, or nothing.
struct RecordNamesTests {
  private let uuid = UUID(uuidString: "01a0e2ed-1be6-72f8-8057-0b0caa945758")!

  @Test func aPersonIsNamedFromThePeopleTableFirst() throws {
    let person = try KitFixture.decode(PersonRead.self, "person")
    let row = PersonLookupItem(ref: .server(uuid), name: "Old name")
    #expect(RecordNames.person(uuid, people: [uuid: person], lookups: [row]) == "Dana Reyes")
    #expect(RecordNames.person(uuid, people: [:], lookups: [row]) == "Old name")
  }

  @Test func aNameThePhoneDoesNotHoldIsNil() {
    #expect(RecordNames.person(uuid, people: [:], lookups: []) == nil)
    #expect(RecordNames.person(nil, people: [:], lookups: []) == nil)
    #expect(RecordNames.contact(uuid, lookups: []) == nil)
    let blank = ContactLookupItem(ref: .server(uuid), name: "  ")
    #expect(RecordNames.contact(uuid, lookups: [blank]) == nil)
  }

  @Test func aContactIsNamedFromThePickersRows() {
    let rows = [
      ContactLookupItem(ref: .local(uuid), name: "Not yet sent"),
      ContactLookupItem(ref: .server(uuid), name: "Big Blue Tech"),
    ]
    #expect(RecordNames.contact(uuid, lookups: rows) == "Big Blue Tech")
  }
}

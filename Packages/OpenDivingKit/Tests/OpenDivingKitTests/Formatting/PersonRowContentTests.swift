import Foundation
import OpenDivingKit
import Testing

/// As the web's `PeopleList` (`src/components/people/people-list.tsx` at `opendiving-web`
/// `50c8ce78`) reads its references against the people table.
struct PersonRowContentTests {
  private static let ana = "01a0e2ed-1be1-7142-996d-0639721e344d"
  private static let ben = "01a0e2ed-1be2-7069-b3e3-7ffb32797bd0"
  private static let unknown = "01a0e2ed-ffff-7000-8000-000000000000"

  private func people() throws -> [UUID: PersonRead] {
    let page = try KitFixture.decode(PaginatedListResponse<PersonRead>.self, "people-page")
    return Dictionary(uniqueKeysWithValues: page.data.map { ($0.uuid, $0) })
  }

  private func references(_ json: String) throws -> [PersonReference] {
    try APICoding.decoder().decode([PersonReference].self, from: Data(json.utf8))
  }

  @Test func namesEachReferenceInTheRecordsOrder() throws {
    let refs = try references(
      #"[{"person_uuid":"\#(Self.ben)","role":"instructor"},"#
        + #"{"person_uuid":"\#(Self.ana)","role":"buddy"}]"#)
    #expect(
      PersonRowContent.rows(refs, people: try people()) == [
        PersonRowContent(name: "Ben Okafor", role: "Instructor"),
        PersonRowContent(name: "Ana Diaz", username: "ana", role: "Buddy"),
      ])
  }

  @Test func dropsAReferenceTheTableCannotResolve() throws {
    let refs = try references(
      #"[{"person_uuid":"\#(Self.unknown)","role":"buddy"},"#
        + #"{"person_uuid":"\#(Self.ana)","role":null}]"#)
    #expect(
      PersonRowContent.rows(refs, people: try people()) == [
        PersonRowContent(name: "Ana Diaz", username: "ana")
      ])
  }

  @Test func aRoleWithoutALabelFallsBackToItsKey() throws {
    let refs = try references(#"[{"person_uuid":"\#(Self.ben)","role":"safety_diver"}]"#)
    #expect(PersonRowContent.rows(refs, people: try people()).map(\.role) == ["Safety diver"])
  }
}

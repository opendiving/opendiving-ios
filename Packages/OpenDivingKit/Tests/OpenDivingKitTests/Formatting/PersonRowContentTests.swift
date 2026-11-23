import Foundation
import OpenDivingKit
import Testing

/// As the web's `PeopleList` (`src/components/people/people-list.tsx` at `opendiving-web`
/// `50c8ce78`) reads its references against the people table.
struct PersonRowContentTests {
  private static let ana = "01a0e2ed-1be1-7142-996d-0639721e344d"
  private static let ben = "01a0e2ed-1be2-7069-b3e3-7ffb32797bd0"
  private static let unknown = "01a0e2ed-ffff-7000-8000-000000000000"
  /// Ana's connected account's picture, as `people-page` carries it.
  private static let anaPicture = ConnectedPicture(
    source: .person(UUID(uuidString: ana)!),
    version: "b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c")

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
        PersonRowContent(uuid: UUID(uuidString: Self.ben), name: "Ben Okafor", role: "Instructor"),
        PersonRowContent(
          uuid: UUID(uuidString: Self.ana), name: "Ana Diaz", username: "ana",
          picture: Self.anaPicture, role: "Buddy"),
      ])
  }

  @Test func dropsAReferenceTheTableCannotResolve() throws {
    let refs = try references(
      #"[{"person_uuid":"\#(Self.unknown)","role":"buddy"},"#
        + #"{"person_uuid":"\#(Self.ana)","role":null}]"#)
    #expect(
      PersonRowContent.rows(refs, people: try people()) == [
        PersonRowContent(
          uuid: UUID(uuidString: Self.ana), name: "Ana Diaz", username: "ana",
          picture: Self.anaPicture)
      ])
  }

  @Test func aPersonTheServerDoesNotHaveYetLinksNowhere() throws {
    let ana = try #require(UUID(uuidString: Self.ana))
    let rows = PersonRowContent.rows(
      [PersonReference(person: .local(ana), role: nil)], people: try people())
    #expect(rows.map(\.name) == ["Ana Diaz"])
    #expect(rows.map(\.uuid) == [nil])
    #expect(rows.map(\.picture) == [nil])
  }

  @Test func aRoleWithoutALabelFallsBackToItsKey() throws {
    let refs = try references(#"[{"person_uuid":"\#(Self.ben)","role":"safety_diver"}]"#)
    #expect(PersonRowContent.rows(refs, people: try people()).map(\.role) == ["Safety diver"])
  }
}

import Foundation
import OpenDivingKit
import Testing

struct RecordRefTests {
  private let uuid = UUID(uuidString: "01A14B2E-0C3D-7A10-9F00-4A2B3C4D5E6F")!

  @Test func aServerRefIsTheBareUUIDAndALocalOneIsPrefixed() throws {
    let refs: [RecordRef] = [.server(uuid), .local(uuid)]
    let text = String(decoding: try APICoding.encoder().encode(refs), as: UTF8.self)
    #expect(
      text
        == #"["01a14b2e-0c3d-7a10-9f00-4a2b3c4d5e6f","local:01a14b2e-0c3d-7a10-9f00-4a2b3c4d5e6f"]"#
    )
    #expect(try APICoding.decoder().decode([RecordRef].self, from: Data(text.utf8)) == refs)
  }

  @Test func anythingElseIsNotARef() {
    #expect(throws: DecodingError.self) {
      try APICoding.decoder().decode([RecordRef].self, from: Data(#"["local:nope"]"#.utf8))
    }
  }

  @Test func aLocalRefInARequestBodyThrowsAndSaysWhere() throws {
    var dive = DiveCreate(
      diveNumber: 1, startTime: try #require(DiveTimestamp(wireValue: "2026-09-14T09:12:00Z")),
      submergedTime: 60)
    dive.diveSites = [.server(UUID()), .local(uuid)]
    #expect(throws: LocalRefOnTheWire.self) { try APICoding.requestEncoder().encode(dive) }
    do {
      _ = try APICoding.requestEncoder().encode(dive)
    } catch let error as LocalRefOnTheWire {
      #expect(error.ref == .local(uuid))
      #expect(error.path == "diveSiteUuids.1")
    }
    // What the phone keeps may hold one.
    _ = try APICoding.encoder().encode(dive)
  }
}

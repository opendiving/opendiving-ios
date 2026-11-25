import Foundation
import Testing

@testable import OpenDivingKit

/// The gear list files its items under the Type picker's headings.
struct GearTypeSectionTests {
  private func item(_ name: String, type: String?) throws -> GearItemRead {
    var object = try #require(
      JSONSerialization.jsonObject(with: KitFixture.data("gear-item")) as? [String: Any])
    object["uuid"] = UUID().uuidString.lowercased()
    object["name"] = name
    object["type"] = type ?? NSNull()
    return try APICoding.decoder().decode(
      GearItemRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func theHeadingsFollowThePickerAndTheItemsTheList() throws {
    let items = try [
      item("Apeks XTX50", type: "regulator"),
      item("Bauer hood", type: "hood"),
      item("Jet fins", type: "fins"),
      item("Mares mask", type: "mask"),
      item("Shearwater Perdix", type: "computer"),
      item("Wing 30 lb", type: "wing"),
    ]
    let sections = GearTypeSection.sections(items)
    #expect(sections.map(\.title) == ["Basics", "Exposure", "SCUBA", "Instruments"])
    #expect(sections[0].items.map(\.name) == ["Jet fins", "Mares mask"])
    #expect(sections[2].items.map(\.name) == ["Apeks XTX50", "Wing 30 lb"])
  }

  @Test func untypedAndUnknownGearFilesUnderOtherLast() throws {
    let items = try [
      item("Bag", type: nil),
      item("Hookah hose", type: "hookah"),
      item("Mask", type: "mask"),
      item("Spare parts", type: "other"),
    ]
    let sections = GearTypeSection.sections(items)
    #expect(sections.map(\.title) == ["Basics", GearTypeSection.other])
    #expect(sections[1].items.map(\.name) == ["Bag", "Hookah hose", "Spare parts"])
  }

  @Test func noGearHasNoHeadings() {
    #expect(GearTypeSection.sections([]).isEmpty)
  }
}

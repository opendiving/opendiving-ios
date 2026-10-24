import Foundation
import OpenDivingKit
import Testing

/// A gear set opened as a checklist, over `gear-sets-page.json`'s *Warm water*: a wetsuit, and
/// an archived 12 L steel cylinder; 4 kg.
struct GearChecklistTests {
  let set: GearSetRead

  init() throws {
    set = try KitFixture.decode(PaginatedListResponse<GearSetRead>.self, "gear-sets-page").data[0]
  }

  @Test func nothingIsTickedWhenTheSetOpensAndTheWeightIsTheSets() {
    let checklist = GearChecklist(set)
    var values = DiveFormValues(weight: 6, gearItems: [.server(UUID())])
    #expect(GearChecklist.replacesGear(in: values))
    checklist.write(into: &values)
    #expect(values.gearItems.isEmpty)
    #expect(values.weight == 4)
    #expect(checklist.items.map(\.isArchived) == [false, true])
    #expect(checklist.filledFields == [.gearItems, .weight])
  }

  @Test func theGearIsTheTickedItemsInTheSetsOrder() {
    var checklist = GearChecklist(set)
    let wetsuit = set.gearItems[0].ref
    let cylinder = set.gearItems[1].ref
    checklist.toggle(cylinder)
    checklist.toggle(wetsuit)
    var values = DiveFormValues()
    checklist.write(into: &values)
    #expect(values.gearItems == [wetsuit, cylinder])
    checklist.toggle(cylinder)
    checklist.write(into: &values)
    #expect(values.gearItems == [wetsuit])
    checklist.toggle(.server(UUID()))
    #expect(checklist.gear == [wetsuit])
    checklist.tickAll()
    #expect(checklist.gear == [wetsuit, cylinder])
  }

  @Test func aSetWithoutAWeightLeavesTheDivesAlone() {
    let checklist = GearChecklist(
      set: .local(UUID()), name: "Cold", items: set.gearItems, weight: nil)
    var values = DiveFormValues(weight: 8)
    checklist.write(into: &values)
    #expect(values.weight == 8)
    #expect(checklist.filledFields == [.gearItems])
    #expect(!GearChecklist.replacesGear(in: DiveFormValues()))
  }

  /// The ticks are what a draft carries as its gear, and the set as its `gear_set_uuid`.
  @Test func aDraftCarriesTheTicksAndTheSet() {
    var checklist = GearChecklist(set)
    checklist.toggle(set.gearItems[0].ref)
    var values = DiveFormValues()
    checklist.write(into: &values)
    let draft = values.draft(gearSet: checklist.set)
    #expect(draft.gearSet == .server(set.uuid))
    #expect(draft.values.gearItems == [set.gearItems[0].ref])
  }

  @Test func aLandedItemKeepsItsTickAndAReleasedSetIsNone() {
    let local = RecordRef.local(UUID())
    let landed = RecordRef.server(UUID())
    let setRef = RecordRef.local(UUID())
    var checklist = GearChecklist(
      set: setRef, name: "New", items: [GearItemInfo(ref: local, name: "Hood")], weight: nil)
    checklist.toggle(local)
    checklist.rewriteRefs { $0 == local ? landed : ($0 == setRef ? nil : $0) }
    #expect(checklist.gear == [landed])
    #expect(checklist.set == nil)
  }

  @Test func keptAndReadBack() throws {
    var checklist = GearChecklist(set)
    checklist.toggle(set.gearItems[1].ref)
    let kept = try APICoding.encoder().encode(checklist)
    #expect(try APICoding.decoder().decode(GearChecklist.self, from: kept) == checklist)
  }
}

import Foundation

// The tanks and the gear: *Tank n* rows over the web's default, cylinders linked from the
// diver's gear, the hint under each tank, and a gear set opened as a checklist whose ticked
// items are the dive's gear from the first tick.
extension DiveFormModel {
  // MARK: - Tanks

  /// *Add tank*: the web's default, 11.1 L of air.
  public func addTank() { change { $0.tanks.append(.added) } }

  public func removeTank(_ index: Int) {
    change { values in
      guard values.tanks.indices.contains(index) else { return }
      values.tanks.remove(at: index)
    }
  }

  /// One tank's change, by index.
  public func changeTank(_ index: Int, _ body: (inout TankValues) -> Void) {
    change { values in
      guard values.tanks.indices.contains(index) else { return }
      body(&values.tanks[index])
    }
  }

  /// Links a tank to a cylinder of the diver's, copying its capacity and making the volume the
  /// vessel's; nil unlinks it and keeps the volume it showed. A picked item that is not a
  /// cylinder is not linked, as the web's picker ignores one created as something else.
  public func linkCylinder(_ ref: RecordRef?, tank index: Int) {
    guard let ref else {
      changeTank(index) { tank in
        tank.volume = tank.shownVolume
        tank.link(nil)
      }
      return
    }
    guard let item = gearInfo(ref), item.type == nil || item.type == "cylinder" else { return }
    changeTank(index) { $0.link(item) }
  }

  /// A gear item as the phone knows it: the lookups', a set's, or one a dive or a search named.
  public func gearInfo(_ ref: RecordRef) -> GearItemInfo? {
    if let item = lookups.gearItems.first(where: { $0.ref == ref }) { return item.info }
    if let item = knownGear[ref] { return item }
    for set in lookups.gearSets {
      if let item = set.items.first(where: { $0.ref == ref }) { return item }
    }
    return checklist?.items.first { $0.ref == ref }
  }

  /// The line under a tank: its gas, its MOD, and — on a dive with one tank, whose depth it was
  /// breathed at — its END or EAD, in the units depths are typed in.
  public func tankHint(_ index: Int) -> String? {
    guard values.tanks.indices.contains(index) else { return nil }
    let tank = values.tanks[index]
    let parts = GasMath.hintParts(
      oxygen: tank.oxygen, helium: tank.helium,
      depth: values.tanks.count == 1 ? values.maxDepth : nil, ppO2: tank.po2Limit,
      units: entryUnits(.depth))
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// The warning under the tanks when the dive's depth is past what its gas allows.
  public var modWarning: String? {
    GasMath.diveModWarning(
      values.tanks.map { OxygenFractions(oxygen: $0.oxygen, helium: $0.helium, usage: $0.usage) },
      maxDepth: values.maxDepth, units: entryUnits(.depth))
  }

  /// The Volume box's presets: the diver's recent volumes, then the families, the diver's own
  /// first.
  public var volumeGroups: [VolumePresetGroup] {
    VolumePresets.groups(for: units, recent: lookups.recentVolumes)
  }

  /// The ppO₂ limits the menu offers, with a recorded value outside them kept in its place.
  public static func po2LimitChoices(_ value: Double?) -> [Double] {
    let options = [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6]
    guard let value, value.isFinite, !options.contains(value) else { return options }
    return (options + [value]).sorted()
  }

  /// Names each tank's linked vessel from the cached gear, where a body or a draft carried the
  /// link alone.
  func attachVessels() {
    for index in values.tanks.indices {
      guard let ref = values.tanks[index].cylinder, values.tanks[index].vessel == nil,
        let item = gearInfo(ref)
      else { continue }
      values.tanks[index].vessel = item
    }
  }

  // MARK: - Gear sets

  /// A set as *Load a gear set…* lists it: `Reef kit (6)`.
  public static func setLabel(_ set: GearSetRow) -> String { "\(set.name) (\(set.items.count))" }

  /// Whether loading a set throws away gear the dive holds, which the web asks about first.
  public var loadingSetReplacesGear: Bool { GearChecklist.replacesGear(in: values) }

  /// The web's confirmation: `Loading "Reef kit" replaces the 2 items currently on this dive.`
  public func replaceSentence(_ set: GearSetRow) -> String {
    "Loading \"\(set.name)\" replaces the "
      + DiveDetailText.countNoun(values.gearItems.count, "item") + " currently on this dive."
  }

  /// Loads a set as a checklist, once confirmed where it replaces gear: the set's weight is the
  /// dive's, nothing is ticked, and the checklist opens.
  public func loadSet(_ set: GearSetRow) {
    let list = GearChecklist(set: set.ref, name: set.name, items: set.items, weight: set.weight)
    remember(gear: set.items)
    checklist = list
    gearSet = set.ref
    visibility.reveal(list.filledFields)
    change { list.write(into: &$0) }
    isChecklistOpen = true
  }

  /// Ticks or unticks a set's item: the dive's gear is the ticked items from now on, beside any
  /// added one by one.
  public func toggleChecklistItem(_ ref: RecordRef) {
    guard var list = checklist else { return }
    list.toggle(ref)
    checklist = list
    writeChecklist()
  }

  /// *Tick all*.
  public func tickAll() {
    guard var list = checklist else { return }
    list.tickAll()
    checklist = list
    writeChecklist()
  }

  /// Opens the loaded set again, ticked as the dive's gear now stands.
  public func reopenChecklist() {
    if let list = checklist, let set = list.set {
      checklist = Self.checklist(
        GearSetRow(ref: set, name: list.name, weight: list.weight, items: list.items),
        ticked: values.gearItems)
    } else if let set = gearSet {
      checklist = rebuiltChecklist(set)
    }
    if checklist != nil { isChecklistOpen = true }
  }

  /// *Use these*: the ticks are already the dive's gear, so this only closes the checklist.
  public func closeChecklist() { isChecklistOpen = false }

  /// The draft's set as a checklist, from the cached sets, ticked as its gear stands.
  func rebuiltChecklist(_ set: RecordRef) -> GearChecklist? {
    guard let row = lookups.gearSets.first(where: { $0.ref == set }) else { return nil }
    remember(gear: row.items)
    return Self.checklist(row, ticked: values.gearItems)
  }

  static func checklist(_ row: GearSetRow, ticked: [RecordRef]) -> GearChecklist {
    var list = GearChecklist(set: row.ref, name: row.name, items: row.items, weight: row.weight)
    for ref in ticked where row.items.contains(where: { $0.ref == ref }) { list.toggle(ref) }
    return list
  }

  /// The ticked items as the dive's gear, keeping what the diver added one by one.
  private func writeChecklist() {
    guard let list = checklist else { return }
    let inSet = Set(list.items.map(\.ref))
    change { values in
      let added = values.gearItems.filter { !inSet.contains($0) }
      values.gearItems = list.gear + added
    }
  }
}

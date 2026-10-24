/// A gear set opened as a checklist at the water's edge: the set, as plain values, and the
/// items ticked on it. Nothing is ticked when the set opens — the point is ticking what is
/// packed — and the ticked items, in the set's order, are the dive's gear from the first pick
/// on, which is also what a draft carries as its gear.
public struct GearChecklist: Codable, Hashable, Sendable {
  /// The set, server's or the phone's own; nil once a discard has released the set, the items
  /// staying as they were loaded. This is a draft's `gear_set_uuid`.
  public private(set) var set: RecordRef?
  public let name: String
  /// In the set's order, archived items included and marked as such.
  public private(set) var items: [GearItemInfo]
  /// Kilograms of ballast the set carries, which a load makes the dive's.
  public let weight: Double?
  public private(set) var ticked: Set<RecordRef> = []

  public init(set: RecordRef, name: String, items: [GearItemInfo], weight: Double?) {
    self.set = set
    self.name = name
    self.items = items
    self.weight = weight
  }

  /// A set as `GET /gear-sets` reads it.
  public init(_ read: GearSetRead) {
    self.init(set: .server(read.uuid), name: read.name, items: read.gearItems, weight: read.weight)
  }

  /// The dive's gear: the ticked items, in the set's order.
  public var gear: [RecordRef] {
    items.map(\.ref).filter(ticked.contains)
  }

  public func isTicked(_ item: RecordRef) -> Bool { ticked.contains(item) }

  /// Ticks an unticked item of the set and unticks a ticked one.
  public mutating func toggle(_ item: RecordRef) {
    guard items.contains(where: { $0.ref == item }) else { return }
    if ticked.contains(item) { ticked.remove(item) } else { ticked.insert(item) }
  }

  /// *Tick all*.
  public mutating func tickAll() {
    ticked = Set(items.map(\.ref))
  }

  /// Whether loading the set into `values` throws away gear they hold, which the web asks
  /// about once before it does (*Replace this dive's gear?*).
  public static func replacesGear(in values: DiveFormValues) -> Bool {
    !values.gearItems.isEmpty
  }

  /// Writes the checklist into the form, as the web's *Load a gear set* writes a set: the gear
  /// is the ticked items, and the weight is the set's where the set records one — a set with
  /// none leaves the dive's alone. Called on the pick and on every tick.
  public func write(into values: inout DiveFormValues) {
    values.gearItems = gear
    if let weight { values.weight = weight }
  }

  /// The fields a load fills, for the form to show where the account hides them.
  public var filledFields: [DiveFormField] {
    weight == nil ? [.gearItems] : [.gearItems, .weight]
  }
}

extension GearChecklist: RewritesLocalRefs {
  /// A dropped item leaves the list and its tick; a dropped set leaves the checklist naming no
  /// set.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    var renamed: [RecordRef: RecordRef] = [:]
    items = items.compactMap { item in
      guard let next = rewrite(item.ref) else { return nil }
      renamed[item.ref] = next
      var copy = item
      copy.ref = next
      return copy
    }
    ticked = Set(ticked.compactMap { renamed[$0] })
    set.rewrite(rewrite)
  }
}

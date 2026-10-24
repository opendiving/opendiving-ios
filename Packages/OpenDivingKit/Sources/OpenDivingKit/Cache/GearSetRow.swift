import Foundation

/// A gear set as the form's *Load a gear set…* lists it and opens it as a checklist: the
/// server's, or one saved on the phone that has not landed, named by ``RecordRef`` either way.
public struct GearSetRow: LookupRow {
  public var ref: RecordRef
  public var name: String
  /// Kilograms of ballast, which the dive's weight is filled from.
  public var weight: Double?
  /// In the set's order, archived ones included.
  public var items: [GearItemInfo]

  public init(ref: RecordRef, name: String, weight: Double? = nil, items: [GearItemInfo] = []) {
    self.ref = ref
    self.name = name
    self.weight = weight
    self.items = items
  }

  public init(_ set: GearSetRead) {
    self.init(ref: .server(set.uuid), name: set.name, weight: set.weight, items: set.gearItems)
  }

  public var title: String { name }
  public var subtitle: String? { nil }

  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    ref = rewrite(ref) ?? ref
    items = items.compactMap { item in
      rewrite(item.ref).map { ref in
        var item = item
        item.ref = ref
        return item
      }
    }
  }
}

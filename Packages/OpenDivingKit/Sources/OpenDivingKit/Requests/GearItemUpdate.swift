/// `PATCH /gear-item/{uuid}`'s body, `GearItemUpdate`: only what is set is sent. The name, the
/// notes, `rented` and `isArchived` cannot be cleared; `isArchived` archives and unarchives the
/// item.
public struct GearItemUpdate: Codable, Hashable, Sendable {
  public var name: String?
  public var brand: Patch<String>
  /// A gear-type key.
  public var type: Patch<String>
  public var notes: String?
  public var rented: Bool?
  public var isArchived: Bool?
  /// Litres of water capacity, above 0.
  public var volume: Patch<Double>
  /// Bar, above 0 and at most 350.
  public var workingPressure: Patch<Double>
  public var material: Patch<String>

  /// An update that changes nothing; set what changed.
  public init() {
    brand = .absent
    type = .absent
    volume = .absent
    workingPressure = .absent
    material = .absent
  }

  /// Archives the item, or brings it back.
  public init(archived: Bool) {
    self.init()
    isArchived = archived
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == GearItemUpdate() }
}

extension GearItemUpdate: RewritesLocalRefs {
  /// An item names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}

/// `POST /gear-set`'s body, `GearSetCreateRequest`.
public struct GearSetCreate: Codable, Hashable, Sendable {
  public var name: String
  /// Kilograms of ballast carried with the set, which a dive's weight is filled from.
  public var weight: Double?
  /// In the set's order.
  public var gearItems: [RecordRef]

  enum CodingKeys: String, CodingKey {
    case name, weight
    case gearItems = "gearItemUuids"
  }

  public init(name: String, weight: Double? = nil, gearItems: [RecordRef] = []) {
    self.name = name
    self.weight = weight
    self.gearItems = gearItems
  }
}

extension GearSetCreate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    gearItems.rewrite(rewrite)
  }
}

/// `PATCH /gear-set/{uuid}`'s body, `GearSetUpdateRequest`: only what is set is sent. The name
/// cannot be cleared; the weight can; the items replace the set's whole list when sent.
public struct GearSetUpdate: Codable, Hashable, Sendable {
  public var name: String?
  public var weight: Patch<Double>
  public var gearItems: [RecordRef]?

  enum CodingKeys: String, CodingKey {
    case name, weight
    case gearItems = "gearItemUuids"
  }

  public init(name: String? = nil, weight: Patch<Double> = .absent, gearItems: [RecordRef]? = nil) {
    self.name = name
    self.weight = weight
    self.gearItems = gearItems
  }
}

extension GearSetUpdate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    if var list = gearItems {
      list.rewrite(rewrite)
      gearItems = list
    }
  }
}

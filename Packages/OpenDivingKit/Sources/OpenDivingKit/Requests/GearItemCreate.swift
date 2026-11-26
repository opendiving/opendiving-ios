/// `POST /gear-item`'s body, `GearItemCreate`. The volume, the working pressure and the
/// material describe a cylinder.
public struct GearItemCreate: Codable, Hashable, Sendable {
  public var name: String
  public var brand: String?
  /// A gear-type key, `regulator` or `cylinder`.
  public var type: String?
  public var notes: String
  /// In the diver's order; nil sends none, so a create queued before records carried links
  /// encodes as it was queued.
  public var links: [WebLink]?
  public var rented: Bool
  /// Litres of water capacity, above 0.
  public var volume: Double?
  /// Bar the vessel is rated to, above 0 and at most 350.
  public var workingPressure: Double?
  public var material: String?

  public init(
    name: String, brand: String? = nil, type: String? = nil, notes: String = "",
    links: [WebLink]? = nil, rented: Bool = false, volume: Double? = nil,
    workingPressure: Double? = nil,
    material: String? = nil
  ) {
    self.name = name
    self.brand = brand
    self.type = type
    self.notes = notes
    self.links = links
    self.rented = rented
    self.volume = volume
    self.workingPressure = workingPressure
    self.material = material
  }
}

extension GearItemCreate: RewritesLocalRefs {
  /// An item names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}

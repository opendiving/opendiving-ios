import Foundation

/// The body of `POST /dive-draft` and `PATCH /dive-draft/{uuid}`: the form's whole state.
///
/// Sent whole on every write, because the server replaces `values` wholesale and sets or
/// clears `gear_set_uuid` whenever it is present — so `gear_set_uuid` is always written, as
/// null when no set is loaded, and a field cleared on one device is cleared on the other. This
/// is also what the phone keeps for a draft it holds.
public struct DiveDraftWrite: Hashable, Sendable {
  /// The gear set the diver loaded as a checklist.
  public var gearSet: RecordRef?
  public var values: DiveDraftValues

  public init(gearSet: RecordRef? = nil, values: DiveDraftValues = DiveDraftValues()) {
    self.gearSet = gearSet
    self.values = values
  }
}

extension DiveDraftWrite: Codable {
  enum CodingKeys: String, CodingKey {
    case gearSet = "gearSetUuid"
    case values
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    gearSet = try c.decodeIfPresent(RecordRef.self, forKey: .gearSet)
    values = try c.decode(DiveDraftValues.self, forKey: .values)
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(gearSet, forKey: .gearSet)
    try c.encode(values, forKey: .values)
  }
}

extension DiveDraftWrite: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    gearSet.rewrite(rewrite)
    values.rewriteRefs(rewrite)
  }
}

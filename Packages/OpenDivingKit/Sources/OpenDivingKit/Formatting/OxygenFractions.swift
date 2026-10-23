/// What the MOD warnings read off one cylinder: its oxygen and helium percentages, each
/// nil when unrecorded, and how it was breathed (`parallel`, `staged`, or nil).
///
/// A recorded `po2_limit` is deliberately not here: it moves the MOD a tank card shows,
/// and must never move the limit a warning judges against.
public struct OxygenFractions: Hashable, Sendable {
  public var oxygen: Double?
  public var helium: Double?
  public var usage: String?

  public init(oxygen: Double?, helium: Double? = nil, usage: String? = nil) {
    self.oxygen = oxygen
    self.helium = helium
    self.usage = usage
  }
}

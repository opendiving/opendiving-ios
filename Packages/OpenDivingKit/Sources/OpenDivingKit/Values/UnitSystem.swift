/// The account's unit preference, as `UserRead.units` names it on the wire.
public enum UnitSystem: String, Sendable, Hashable, CaseIterable, Codable {
  case metric
  case imperial
}

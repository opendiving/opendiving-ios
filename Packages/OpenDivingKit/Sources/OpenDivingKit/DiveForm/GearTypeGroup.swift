/// One run of gear types in the Type picker, under a heading or, with none, under a rule.
public struct GearTypeGroup: Hashable, Sendable {
  public let title: String?
  public let types: [String]
}

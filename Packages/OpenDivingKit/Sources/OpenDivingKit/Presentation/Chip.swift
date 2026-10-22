/// One chip over a record's title.
public struct Chip: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// A bordered abbreviation from one of the API's vocabularies (`FW`, `CCR`), whose
    /// accessibility label is the term in full.
    case vocabulary
    /// One of the diver's own tags, filled, its words its own.
    case tag
  }

  public var text: String
  public var accessibilityLabel: String
  public var kind: Kind

  public init(text: String, accessibilityLabel: String, kind: Kind) {
    self.text = text
    self.accessibilityLabel = accessibilityLabel
    self.kind = kind
  }

  /// A tag chip, whose label is its own text.
  public static func tag(_ text: String) -> Chip {
    Chip(text: text, accessibilityLabel: text, kind: .tag)
  }
}

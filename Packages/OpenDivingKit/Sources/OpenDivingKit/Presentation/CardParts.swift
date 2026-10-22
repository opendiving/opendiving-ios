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

/// One item of the dot-separated line under a title: text, an icon with text (the boat
/// and its name), or an icon alone (the paperclip of an attached recording), which then
/// needs an accessibility label to be read at all.
public struct Fact: Hashable, Sendable {
  public var text: String?
  /// An SF Symbols name.
  public var systemImage: String?
  public var accessibilityLabel: String?

  public init(text: String? = nil, systemImage: String? = nil, accessibilityLabel: String? = nil) {
    self.text = text
    self.systemImage = systemImage
    self.accessibilityLabel = accessibilityLabel
  }
}

/// A labelled figure — *Dive time 48 min* — with the value already formatted. A nil value
/// is drawn as a muted dash: an absence at full contrast reads as a value.
public struct Figure: Hashable, Sendable {
  public var label: String
  public var value: String?

  public init(label: String, value: String?) {
    self.label = label
    self.value = value
  }
}

/// A named place on a map.
public struct MapPoint: Hashable, Sendable {
  public var name: String
  public var latitude: Double
  public var longitude: Double

  public init(name: String, latitude: Double, longitude: Double) {
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
  }
}

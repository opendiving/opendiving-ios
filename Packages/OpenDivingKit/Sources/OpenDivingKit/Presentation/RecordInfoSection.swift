/// A group of a record's own fields, behind a detail page's Info button.
public struct RecordInfoSection: Hashable, Sendable {
  public var heading: String?
  public var facts: [RecordInfoFact]

  public init(heading: String? = nil, facts: [RecordInfoFact]) {
    self.heading = heading
    self.facts = facts
  }
}

/// One field of a record. Every field its form has is listed, so nil is one left unrecorded, as
/// an empty value is.
public struct RecordInfoFact: Hashable, Sendable {
  public var label: String
  public var value: String?
  /// Free text a label's row would squeeze, drawn under its label.
  public var isWide: Bool

  public init(label: String, value: String?, isWide: Bool = false) {
    self.label = label
    self.value = value?.isEmpty == true ? nil : value
    self.isWide = isWide
  }
}

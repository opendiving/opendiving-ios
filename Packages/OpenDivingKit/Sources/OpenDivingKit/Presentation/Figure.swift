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

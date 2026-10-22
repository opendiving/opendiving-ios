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

/// One item of the dot-separated line under a title: text, an icon with text (the boat
/// and its name), or an icon alone (the paperclip of an attached recording), which then
/// needs an accessibility label to be read at all.
public struct Fact: Hashable, Sendable {
  public var text: String?
  public var icon: Icon?
  public var accessibilityLabel: String?

  public init(text: String? = nil, icon: Icon? = nil, accessibilityLabel: String? = nil) {
    self.text = text
    self.icon = icon
    self.accessibilityLabel = accessibilityLabel
  }
}

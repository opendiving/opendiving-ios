/// One item of the dot-separated line under a title: text, an icon with text (the boat
/// and its name), or icons alone (a dive computer for each recording), which then need an
/// accessibility label to be read at all.
public struct Fact: Hashable, Sendable {
  public var text: String?
  public var icon: Icon?
  /// How many of the icon draw side by side, where there is no text.
  public var iconCount: Int
  public var accessibilityLabel: String?

  public init(
    text: String? = nil, icon: Icon? = nil, iconCount: Int = 1, accessibilityLabel: String? = nil
  ) {
    self.text = text
    self.icon = icon
    self.iconCount = iconCount
    self.accessibilityLabel = accessibilityLabel
  }
}

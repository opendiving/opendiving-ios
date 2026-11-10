/// A short label in a capsule beside a record's title, in one of the web's badge variants.
public struct Badge: Hashable, Sendable {
  public enum Style: Hashable, Sendable {
    /// The web's `default`: the foreground's own dark fill, as a completed course.
    case primary
    /// Muted fill, as Rented and a gas name.
    case secondary
    /// Bordered, no fill, as Archived, a site's mark and an agency.
    case outline
    /// Amber, as a course still incomplete.
    case warning
    /// The brand's teal, as a gas role, a site's tags and gear in service.
    case teal
    /// The brand's coral, as a card nearing expiry and service due soon.
    case coral
    /// As an expired card and overdue service.
    case destructive
  }

  public var text: String
  public var style: Style

  public init(_ text: String, style: Style = .secondary) {
    self.text = text
    self.style = style
  }
}

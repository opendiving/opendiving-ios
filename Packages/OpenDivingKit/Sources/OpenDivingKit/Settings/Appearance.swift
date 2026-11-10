/// Light, dark, or the phone's own: the phone's choice, kept for no server and no account.
public enum Appearance: String, CaseIterable, Hashable, Sendable, Identifiable, Codable {
  case light
  case dark
  case system

  public var id: Self { self }

  public var title: String {
    switch self {
    case .light: "Light"
    case .dark: "Dark"
    case .system: "System"
    }
  }

  public var icon: Icon {
    switch self {
    case .light: .sun
    case .dark: .moon
    case .system: .monitor
    }
  }
}

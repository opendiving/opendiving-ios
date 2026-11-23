/// One section of *Settings*, in the order the web's settings navigation lists them, each a row
/// on the list pushing its own screen.
public enum SettingsSection: String, CaseIterable, Hashable, Sendable, Identifiable {
  case account
  case checkin
  case authentication
  case data
  case notifications
  case preferences

  public var id: Self { self }

  public var title: String {
    switch self {
    case .account: "Account"
    case .checkin: "Check-in"
    case .authentication: "Authentication"
    case .data: "Data"
    case .notifications: "Notifications"
    case .preferences: "Preferences"
    }
  }

  public var icon: Icon {
    switch self {
    case .account: .user
    case .checkin: .clipboardList
    case .authentication: .keyRound
    case .data: .hardDrive
    case .notifications: .bell
    case .preferences: .slidersHorizontal
    }
  }
}

import Foundation

/// One section of *Settings*, in the order the web's settings navigation lists them, each a row
/// on the list pushing its own screen.
public enum SettingsSection: String, CaseIterable, Hashable, Sendable, Identifiable {
  case account
  case checkin
  case authentication
  case data
  case notifications
  case preferences
  case invitations

  public var id: Self { self }

  public var title: String {
    switch self {
    case .account: "Account"
    case .checkin: "Check-in"
    case .authentication: "Authentication"
    case .data: "Data"
    case .notifications: "Notifications"
    case .preferences: "Preferences"
    case .invitations: "Invitations"
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
    case .invitations: .mailPlus
    }
  }

  /// The section's page on the web app, which is served from the server's own origin.
  public func webURL(on origin: ServerOrigin) -> URL {
    origin.url.appendingPathComponent("settings", isDirectory: true)
      .appendingPathComponent(rawValue, isDirectory: false)
  }

  /// The sections a server offers: every one, except *Invitations* once the server has said
  /// anyone may register, which leaves nobody to invite. Until it has answered the row stays,
  /// since the screen behind it answers for itself either way.
  public static func offered(by config: InstanceConfigRead?) -> [SettingsSection] {
    allCases.filter { $0 != .invitations || config?.registrationMode != "open" }
  }
}

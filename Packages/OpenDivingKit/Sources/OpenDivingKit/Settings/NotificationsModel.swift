import Observation

/// *Notifications*: a switch per scheduled email, each saving on change with its own key.
@MainActor
@Observable
public final class NotificationsModel {
  public let write: AccountWrite
  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    write = AccountWrite(session: session)
  }

  public var preferences: [EmailPreference] { EmailPreference.allCases }

  /// The switch as the account has it, or as the diver just set it.
  public func isOn(_ preference: EmailPreference) -> Bool {
    write.shown.flatMap(preference.value(in:)) ?? preference.isOn(for: session.user)
  }

  public func set(_ preference: EmailPreference, _ on: Bool) async {
    guard on != isOn(preference) else { return }
    await write.save(preference.update(on))
  }
}

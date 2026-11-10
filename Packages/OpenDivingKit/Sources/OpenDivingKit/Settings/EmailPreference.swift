/// One of the scheduled emails *Notifications* switches, each on unless the diver turned it off,
/// in the web's order and words.
public enum EmailPreference: String, CaseIterable, Hashable, Sendable, Identifiable {
  case gearService
  case renewalReminder
  case yearInReview

  public var id: Self { self }

  public var label: String {
    switch self {
    case .gearService: "Remind me when gear is due for service"
    case .renewalReminder: "Remind me when a certification or my insurance is expiring"
    case .yearInReview: "Send me my year in review"
    }
  }

  public var description: String {
    switch self {
    case .gearService:
      "A single email listing anything coming due — regulator services, cylinder inspections and"
        + " tests, computer batteries. One when something is approaching, one when it's overdue."
    case .renewalReminder:
      "A single email listing every card and insurance policy within"
        + " \(CertificationExpiry.expiringSoonDays) days of its expiry date. One as it enters that"
        + " window, one when it expires."
    case .yearInReview:
      "Each January, last year's diving in figures — dives and time underwater, the deepest and"
        + " longest, sites and species. Never for a year with no dives."
    }
  }

  /// Whether `user` gets it; on before the account is known, as the server defaults it.
  public func isOn(for user: UserRead?) -> Bool {
    guard let user else { return true }
    return switch self {
    case .gearService: user.gearServiceEmails
    case .renewalReminder: user.renewalReminderEmails
    case .yearInReview: user.yearInReviewEmails
    }
  }

  /// What the switch is set to in `update`, or nil when the update leaves it.
  public func value(in update: UserUpdate) -> Bool? {
    switch self {
    case .gearService: update.gearServiceEmails
    case .renewalReminder: update.renewalReminderEmails
    case .yearInReview: update.yearInReviewEmails
    }
  }

  /// The write that sets this one switch and nothing else.
  public func update(_ on: Bool) -> UserUpdate {
    switch self {
    case .gearService: UserUpdate(gearServiceEmails: on)
    case .renewalReminder: UserUpdate(renewalReminderEmails: on)
    case .yearInReview: UserUpdate(yearInReviewEmails: on)
    }
  }
}

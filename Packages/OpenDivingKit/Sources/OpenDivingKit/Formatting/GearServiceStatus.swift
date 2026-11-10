/// How urgent a servicing rule is, as the gear list's badge says it: the web's
/// `serviceStatus`, a twin of the API's own for its reminder email, so the three agree.
///
/// The API sends due points only, never a status, which depends on the day it is read.
public enum GearServiceStatus: Hashable, Sendable {
  case ok
  case dueSoon
  case overdue

  /// How far ahead a due date reads as due soon: the lead time for booking a regulator in.
  public static let dueSoonDays = 30
  /// The dive-count equivalent, about a trip's diving.
  public static let dueSoonDives = 10
  /// The hours-of-diving equivalent, compared in seconds of dive time.
  public static let dueSoonHours = 10

  /// Every arm is weighed and the most urgent wins — *annually or every 100 dives, whichever
  /// comes first*. A paused rule is always ``ok``. `diveTime` is the item's, in seconds.
  public init(
    _ schedule: some GearServiceDue, diveCount: Int, diveTime: Int, today: CalendarDate
  ) {
    guard schedule.isActive else {
      self = .ok
      return
    }
    var dueSoon = false
    if let due = schedule.nextDueOn {
      let days = due.daysSinceEpoch - today.daysSinceEpoch
      if days <= 0 {
        self = .overdue
        return
      }
      if days <= Self.dueSoonDays { dueSoon = true }
    }
    if let threshold = schedule.nextDueAtDiveCount {
      let remaining = threshold - diveCount
      if remaining <= 0 {
        self = .overdue
        return
      }
      if remaining <= Self.dueSoonDives { dueSoon = true }
    }
    if let threshold = schedule.nextDueAtDiveTime {
      let remaining = threshold - diveTime
      if remaining <= 0 {
        self = .overdue
        return
      }
      if remaining <= Self.dueSoonHours * GearServiceText.secondsPerHour { dueSoon = true }
    }
    self = dueSoon ? .dueSoon : .ok
  }

  /// The most urgent status across an item's rules, for the one badge on its card
  /// (`worstServiceStatus`). Nil when no rule is active: nothing is being watched, which is
  /// not everything being fine.
  public static func worst<Schedule: GearServiceDue>(
    _ schedules: [Schedule], diveCount: Int, diveTime: Int, today: CalendarDate
  ) -> GearServiceStatus? {
    let statuses = schedules.filter(\.isActive).map {
      GearServiceStatus($0, diveCount: diveCount, diveTime: diveTime, today: today)
    }
    if statuses.isEmpty { return nil }
    if statuses.contains(.overdue) { return .overdue }
    if statuses.contains(.dueSoon) { return .dueSoon }
    return .ok
  }

  /// `serviceStatusLabel`.
  public var label: String {
    switch self {
    case .overdue: "Overdue"
    case .dueSoon: "Due soon"
    case .ok: "In service"
    }
  }
}

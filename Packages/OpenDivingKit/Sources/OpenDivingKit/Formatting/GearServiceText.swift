/// When gear is next due for service, in the web's words (`lib/gear-service.ts`): the gear
/// page's *Next service* and each rule's due line.
public enum GearServiceText {
  static let secondsPerHour = 3600

  /// When an item's next service falls (`nextService`).
  public enum NextService: Hashable, Sendable {
    /// A dive count or an hours figure has run out, so no date says anything.
    case overdue
    /// The earliest due date, a past one included.
    case date(CalendarDate)
    case dives(remaining: Int)
    /// Hours of diving, rounded up.
    case hours(remaining: Int)
  }

  /// A remainder of dive time as whole hours, rounded up — forty minutes left is an hour — as
  /// the API's `hours_of_diving` rounds it (`hoursOfDiving`).
  public static func hoursOfDiving(_ seconds: Int) -> Int {
    Int((Double(seconds) / Double(secondsPerHour)).rounded(.up))
  }

  /// Read off each active rule's urgent arm: ``NextService/overdue`` when a dive count or an
  /// hours figure has run out; else the earliest due date; else the fewest dives left; else the
  /// fewest hours. Nil when no active rule has an arm.
  public static func nextService<Schedule: GearServiceDue>(
    _ schedules: [Schedule], diveCount: Int, diveTime: Int, today: CalendarDate
  ) -> NextService? {
    var date: CalendarDate?
    var dives: Int?
    var hours: Int?
    for schedule in schedules where schedule.isActive {
      guard
        let due = urgentArm(schedule, diveCount: diveCount, diveTime: diveTime, today: today)
      else { continue }
      if due.unit == .day, let on = schedule.nextDueOn {
        if date.map({ on < $0 }) ?? true { date = on }
        continue
      }
      if due.overdue { return .overdue }
      if due.unit == .dive {
        dives = min(dives ?? due.count, due.count)
      } else {
        hours = min(hours ?? due.count, due.count)
      }
    }
    if let date { return .date(date) }
    if let dives { return .dives(remaining: dives) }
    if let hours { return .hours(remaining: hours) }
    return nil
  }

  /// *Overdue by 3 dives*, *Due in 10 days*, *Due in 12 hours of diving*, *Overdue (due
  /// today)* (`formatServiceDue`). Due today is already overdue, as the badge says.
  public static func due(
    _ schedule: some GearServiceDue, diveCount: Int, diveTime: Int, today: CalendarDate
  ) -> String {
    guard
      let due = urgentArm(schedule, diveCount: diveCount, diveTime: diveTime, today: today)
    else { return "No due date" }
    if due.overdue {
      if due.unit == .day, due.count == 0 { return "Overdue (due today)" }
      return "Overdue by " + countOf(due.count, due.unit)
    }
    return "Due in " + countOf(due.count, due.unit)
  }

  enum Unit {
    case day, dive, hour
  }

  /// *3 dives*, *1 day*, *12 hours of diving*: an hours figure always says it is diving, so it
  /// never reads as clock hours (`countOf`).
  static func countOf(_ count: Int, _ unit: Unit) -> String {
    switch unit {
    case .day: DiveDetailText.countNoun(count, "day")
    case .dive: DiveDetailText.countNoun(count, "dive")
    case .hour: DiveDetailText.countNoun(count, "hour") + " of diving"
    }
  }

  /// When one rule is next due, by whichever arm is urgent (`nextServiceDue`): an overdue dive
  /// or hours arm over a date that is not overdue, the dive arm before the hours arm, and
  /// otherwise the date, the arm divers think in.
  static func urgentArm(
    _ schedule: some GearServiceDue, diveCount: Int, diveTime: Int, today: CalendarDate
  ) -> (overdue: Bool, count: Int, unit: Unit)? {
    let days = schedule.nextDueOn.map { $0.daysSinceEpoch - today.daysSinceEpoch }
    let remaining = schedule.nextDueAtDiveCount.map { $0 - diveCount }
    let timeRemaining = schedule.nextDueAtDiveTime.map { $0 - diveTime }
    let dateOverdue = days.map { $0 <= 0 } ?? false
    if let remaining, remaining <= 0, !dateOverdue { return (true, -remaining, .dive) }
    if let timeRemaining, timeRemaining <= 0, !dateOverdue {
      return (true, hoursOfDiving(-timeRemaining), .hour)
    }
    if let days {
      return dateOverdue ? (true, -days, .day) : (false, days, .day)
    }
    if let remaining { return (false, remaining, .dive) }
    if let timeRemaining { return (false, hoursOfDiving(timeRemaining), .hour) }
    return nil
  }
}

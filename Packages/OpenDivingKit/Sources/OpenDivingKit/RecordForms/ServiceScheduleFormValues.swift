import Foundation

/// The service schedule dialog's values and rules (`gearServiceScheduleSchema`): a kind, a label
/// beside it, the day it counts from, and three intervals of which at least one is set.
public struct ServiceScheduleFormValues: Hashable, Sendable {
  public var gearItem: RecordRef
  /// A service-kind key.
  public var kind: String
  public var label: String
  public var startsOn: CalendarDate?
  public var intervalMonths: Int?
  public var intervalDives: Int?
  public var intervalHours: Int?

  /// The API's ceilings on each interval, past any service rule.
  public static let intervalMonthsMax = 1_200
  public static let intervalDivesMax = 1_000_000
  public static let intervalHoursMax = 1_000_000

  public init(
    gearItem: RecordRef, kind: String = "service", label: String = "",
    startsOn: CalendarDate? = nil, intervalMonths: Int? = nil, intervalDives: Int? = nil,
    intervalHours: Int? = nil
  ) {
    self.gearItem = gearItem
    self.kind = kind
    self.label = label
    self.startsOn = startsOn
    self.intervalMonths = intervalMonths
    self.intervalDives = intervalDives
    self.intervalHours = intervalHours
  }

  /// A new schedule: the gear type's first preset, in service since `today`.
  public init(gearItem: RecordRef, gearType: String?, today: CalendarDate) {
    let preset = ServiceSchedulePreset.defaults(forGearType: gearType).first
    self.init(
      gearItem: gearItem, kind: preset?.kind ?? "service", startsOn: today,
      intervalMonths: preset?.intervalMonths, intervalDives: preset?.intervalDives)
  }

  /// The form an edit opens on.
  public init(editing schedule: GearServiceScheduleRead) {
    self.init(
      gearItem: .server(schedule.gearItemUuid), kind: schedule.kind, label: schedule.label ?? "",
      startsOn: schedule.startsOn, intervalMonths: schedule.intervalMonths,
      intervalDives: schedule.intervalDives, intervalHours: schedule.intervalHours)
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("label", FormText.length(label, "Label", max: 120))
    if startsOn == nil { list.add("starts_on", "An in-service date is required") }
    list.add(
      "interval_months",
      Self.intervalIssue(intervalMonths, "Interval in months", max: Self.intervalMonthsMax))
    list.add(
      "interval_dives",
      Self.intervalIssue(intervalDives, "Interval in dives", max: Self.intervalDivesMax))
    list.add(
      "interval_hours",
      Self.intervalIssue(intervalHours, "Interval in hours", max: Self.intervalHoursMax))
    if intervalMonths == nil, intervalDives == nil, intervalHours == nil {
      // The API's and the database's rule too: a rule with no interval never falls due.
      list.add("interval_months", "Set an interval in months, in dives or in hours of diving")
    }
    return list.issues
  }

  static func intervalIssue(_ value: Int?, _ label: String, max: Int) -> String? {
    guard let value else { return nil }
    if value <= 0 { return "\(label) must be greater than zero" }
    if value > max { return "\(label) cannot exceed \(NumberText.grouped(max))" }
    return nil
  }

  /// `POST /gear-service-schedule`'s body, the label trimmed.
  public func toCreate() throws(FormInvalid) -> GearServiceScheduleCreate {
    guard issues.isEmpty, let startsOn else { throw FormInvalid(issues: issues) }
    return GearServiceScheduleCreate(
      gearItem: gearItem, kind: kind, startsOn: startsOn,
      label: FormText.trimmedOrNil(label), intervalMonths: intervalMonths,
      intervalDives: intervalDives, intervalHours: intervalHours)
  }

  /// `PATCH /gear-service-schedule/{uuid}`'s body: what differs from the values the form opened
  /// on, a cleared interval sent as null.
  public func diff(from baseline: ServiceScheduleFormValues) throws(FormInvalid)
    -> GearServiceScheduleUpdate
  {
    let now = try toCreate()
    var update = GearServiceScheduleUpdate()
    if now.kind != baseline.kind { update.kind = now.kind }
    if now.startsOn != baseline.startsOn { update.startsOn = now.startsOn }
    update.label = .change(from: FormText.trimmedOrNil(baseline.label), to: now.label)
    update.intervalMonths = .change(from: baseline.intervalMonths, to: now.intervalMonths)
    update.intervalDives = .change(from: baseline.intervalDives, to: now.intervalDives)
    update.intervalHours = .change(from: baseline.intervalHours, to: now.intervalHours)
    return update
  }

  /// These values with a queued update laid over; a pause or a resume changes nothing here.
  public func applying(_ update: GearServiceScheduleUpdate) -> ServiceScheduleFormValues {
    var next = self
    if let kind = update.kind { next.kind = kind }
    if let startsOn = update.startsOn { next.startsOn = startsOn }
    next.label = update.label.applied(to: label) ?? ""
    next.intervalMonths = update.intervalMonths.applied(to: intervalMonths)
    next.intervalDives = update.intervalDives.applied(to: intervalDives)
    next.intervalHours = update.intervalHours.applied(to: intervalHours)
    return next
  }

  /// What a typed interval holds: a whole number, nil while the box is blank or holds none.
  public static func interval(_ text: String) -> Int? {
    Int(text.trimmingCharacters(in: .whitespaces))
  }
}

extension ServiceScheduleFormValues: GearServiceEditValues {
  public func operation() throws(FormInvalid) -> OutboxOperation {
    .createServiceSchedule(try toCreate())
  }

  public init?(reopening operation: OutboxOperation) {
    guard case .createServiceSchedule(let body) = operation else { return nil }
    self.init(
      gearItem: body.gearItem, kind: body.kind, label: body.label ?? "", startsOn: body.startsOn,
      intervalMonths: body.intervalMonths, intervalDives: body.intervalDives,
      intervalHours: body.intervalHours)
  }

  public func update(of ref: RecordRef, from baseline: ServiceScheduleFormValues)
    throws(FormInvalid) -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateServiceSchedule(ref, gearItem: gearItem, update)
  }

  public func applying(_ operation: OutboxOperation) -> ServiceScheduleFormValues {
    if case .updateServiceSchedule(_, _, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef, gearItem: RecordRef) -> OutboxOperation {
    .deleteServiceSchedule(ref, gearItem: gearItem)
  }
}

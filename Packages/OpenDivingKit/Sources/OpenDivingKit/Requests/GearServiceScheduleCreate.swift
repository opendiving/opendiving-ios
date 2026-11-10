/// `POST /gear-service-schedule`'s body, `GearServiceScheduleCreate`: a servicing rule for one
/// gear item, with at least one interval.
public struct GearServiceScheduleCreate: Codable, Hashable, Sendable {
  /// The item the rule is for. A rule cannot go on without it.
  public var gearItem: RecordRef
  /// A service-kind key (``GearServiceKinds/all``).
  public var kind: String
  /// The day the first due date is measured from.
  public var startsOn: CalendarDate
  public var label: String?
  public var intervalMonths: Int?
  public var intervalDives: Int?
  public var intervalHours: Int?

  enum CodingKeys: String, CodingKey {
    case kind, startsOn, label, intervalMonths, intervalDives, intervalHours
    case gearItem = "gearItemUuid"
  }

  public init(
    gearItem: RecordRef, kind: String, startsOn: CalendarDate, label: String? = nil,
    intervalMonths: Int? = nil, intervalDives: Int? = nil, intervalHours: Int? = nil
  ) {
    self.gearItem = gearItem
    self.kind = kind
    self.startsOn = startsOn
    self.label = label
    self.intervalMonths = intervalMonths
    self.intervalDives = intervalDives
    self.intervalHours = intervalHours
  }
}

extension GearServiceScheduleCreate: RewritesLocalRefs {
  /// The item is kept when dropped: the rule is withdrawn with it, never sent without it.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    gearItem = rewrite(gearItem) ?? gearItem
  }
}

/// `PATCH /gear-service-schedule/{uuid}`'s body, `GearServiceScheduleUpdate`: only what is set
/// is sent. The kind, the start and `isActive` cannot be cleared; an interval can, while one
/// stays. `isActive` pauses and resumes the rule.
public struct GearServiceScheduleUpdate: Codable, Hashable, Sendable {
  public var kind: String?
  public var label: Patch<String>
  public var startsOn: CalendarDate?
  public var intervalMonths: Patch<Int>
  public var intervalDives: Patch<Int>
  public var intervalHours: Patch<Int>
  public var isActive: Bool?

  /// An update that changes nothing; set what changed.
  public init() {
    label = .absent
    intervalMonths = .absent
    intervalDives = .absent
    intervalHours = .absent
  }

  /// Pauses the rule's reminders, or resumes them.
  public init(active: Bool) {
    self.init()
    isActive = active
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == GearServiceScheduleUpdate() }
}

extension GearServiceScheduleUpdate: RewritesLocalRefs {
  /// A rule's update names no other record.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {}
}

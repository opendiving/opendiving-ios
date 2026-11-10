/// `POST /gear-service-record`'s body, `GearServiceRecordCreate`: a service logged on one gear
/// item. With no schedule named, the API links the item's one rule of the same kind and label.
public struct GearServiceRecordCreate: Codable, Hashable, Sendable {
  /// The item serviced. A service cannot go on without it.
  public var gearItem: RecordRef
  /// The rule it satisfies.
  public var schedule: RecordRef?
  /// The shop that did the work.
  public var contact: RecordRef?
  /// A service-kind key.
  public var kind: String
  public var servicedOn: CalendarDate
  public var label: String?
  public var performedBy: String?
  public var notes: String

  enum CodingKeys: String, CodingKey {
    case kind, servicedOn, label, performedBy, notes
    case gearItem = "gearItemUuid"
    case schedule = "gearServiceScheduleUuid"
    case contact = "contactUuid"
  }

  public init(
    gearItem: RecordRef, schedule: RecordRef? = nil, contact: RecordRef? = nil, kind: String,
    servicedOn: CalendarDate, label: String? = nil, performedBy: String? = nil, notes: String = ""
  ) {
    self.gearItem = gearItem
    self.schedule = schedule
    self.contact = contact
    self.kind = kind
    self.servicedOn = servicedOn
    self.label = label
    self.performedBy = performedBy
    self.notes = notes
  }
}

extension GearServiceRecordCreate: RewritesLocalRefs {
  /// The item is kept when dropped: the service is withdrawn with it, never sent without it.
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    gearItem = rewrite(gearItem) ?? gearItem
    schedule.rewrite(rewrite)
    contact.rewrite(rewrite)
  }
}

/// `PATCH /gear-service-record/{uuid}`'s body, `GearServiceRecordUpdateRequest`: only what is set
/// is sent. The kind, the day and the notes cannot be cleared; a null contact unlinks the shop.
public struct GearServiceRecordUpdate: Codable, Hashable, Sendable {
  public var kind: String?
  public var servicedOn: CalendarDate?
  public var label: Patch<String>
  public var performedBy: Patch<String>
  public var notes: String?
  public var contact: Patch<RecordRef>

  enum CodingKeys: String, CodingKey {
    case kind, servicedOn, label, performedBy, notes
    case contact = "contactUuid"
  }

  /// An update that changes nothing; set what changed.
  public init() {
    label = .absent
    performedBy = .absent
    contact = .absent
  }

  /// Whether sending it would change nothing.
  public var isEmpty: Bool { self == GearServiceRecordUpdate() }
}

extension GearServiceRecordUpdate: RewritesLocalRefs {
  public mutating func rewriteRefs(_ rewrite: (RecordRef) -> RecordRef?) {
    contact.rewrite(rewrite)
  }
}

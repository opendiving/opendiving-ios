import Foundation

/// The *Log Service* dialog's values and rules (`gearServiceRecordSchema`). The label is not a
/// field: it comes from the schedule the service is logged against, or the service edited.
public struct ServiceRecordFormValues: Hashable, Sendable {
  public var gearItem: RecordRef
  /// The rule a new service satisfies; nil lets the API link the one of the same kind and label.
  public var schedule: RecordRef?
  /// A service-kind key.
  public var kind: String
  public var label: String
  public var servicedOn: CalendarDate?
  /// The shop, a contact.
  public var contact: RecordRef?
  public var performedBy: String
  public var notes: String

  public init(
    gearItem: RecordRef, schedule: RecordRef? = nil, kind: String = "service", label: String = "",
    servicedOn: CalendarDate? = nil, contact: RecordRef? = nil, performedBy: String = "",
    notes: String = ""
  ) {
    self.gearItem = gearItem
    self.schedule = schedule
    self.kind = kind
    self.label = label
    self.servicedOn = servicedOn
    self.contact = contact
    self.performedBy = performedBy
    self.notes = notes
  }

  /// A new service, done `today`, of `schedule`'s kind and label where it is logged against one.
  public init(gearItem: RecordRef, schedule: GearServiceScheduleRead?, today: CalendarDate) {
    self.init(
      gearItem: gearItem, schedule: schedule.map { .server($0.uuid) },
      kind: schedule?.kind ?? "service", label: schedule?.label ?? "", servicedOn: today)
  }

  /// The form an edit opens on.
  public init(editing record: GearServiceRecordRead) {
    self.init(
      gearItem: .server(record.gearItemUuid), kind: record.kind, label: record.label ?? "",
      servicedOn: record.servicedOn, contact: record.contactUuid.map(RecordRef.server),
      performedBy: record.performedBy ?? "", notes: record.notes)
  }

  public var issues: [FormIssue] {
    var list = FormIssueList()
    list.add("label", FormText.length(label, "Label", max: 120))
    if servicedOn == nil { list.add("serviced_on", "A service date is required") }
    list.add("performed_by", FormText.length(performedBy, "Serviced by", max: 255))
    list.add("notes", FormText.length(notes, "Notes", max: DiveFormBounds.notesMax))
    return list.issues
  }

  /// `POST /gear-service-record`'s body: the label trimmed, a blank *Serviced by* left out.
  public func toCreate() throws(FormInvalid) -> GearServiceRecordCreate {
    guard issues.isEmpty, let servicedOn else { throw FormInvalid(issues: issues) }
    return GearServiceRecordCreate(
      gearItem: gearItem, schedule: schedule, contact: contact, kind: kind,
      servicedOn: servicedOn, label: FormText.trimmedOrNil(label),
      performedBy: performedBy.isEmpty ? nil : performedBy, notes: notes)
  }

  /// `PATCH /gear-service-record/{uuid}`'s body: what differs from the values the form opened on.
  public func diff(from baseline: ServiceRecordFormValues) throws(FormInvalid)
    -> GearServiceRecordUpdate
  {
    let now = try toCreate()
    var update = GearServiceRecordUpdate()
    if now.kind != baseline.kind { update.kind = now.kind }
    if now.servicedOn != baseline.servicedOn { update.servicedOn = now.servicedOn }
    if now.notes != baseline.notes { update.notes = now.notes }
    update.label = .change(from: FormText.trimmedOrNil(baseline.label), to: now.label)
    update.performedBy = .change(
      from: baseline.performedBy.isEmpty ? nil : baseline.performedBy, to: now.performedBy)
    update.contact = .change(from: baseline.contact, to: now.contact)
    return update
  }

  /// These values with a queued update laid over.
  public func applying(_ update: GearServiceRecordUpdate) -> ServiceRecordFormValues {
    var next = self
    if let kind = update.kind { next.kind = kind }
    if let servicedOn = update.servicedOn { next.servicedOn = servicedOn }
    if let notes = update.notes { next.notes = notes }
    next.label = update.label.applied(to: label) ?? ""
    next.performedBy = update.performedBy.applied(to: performedBy) ?? ""
    next.contact = update.contact.applied(to: contact)
    return next
  }
}

extension ServiceRecordFormValues: GearServiceEditValues {
  public func operation() throws(FormInvalid) -> OutboxOperation {
    .createServiceRecord(try toCreate())
  }

  public init?(reopening operation: OutboxOperation) {
    guard case .createServiceRecord(let body) = operation else { return nil }
    self.init(
      gearItem: body.gearItem, schedule: body.schedule, kind: body.kind, label: body.label ?? "",
      servicedOn: body.servicedOn, contact: body.contact, performedBy: body.performedBy ?? "",
      notes: body.notes)
  }

  public func update(of ref: RecordRef, from baseline: ServiceRecordFormValues)
    throws(FormInvalid) -> OutboxOperation?
  {
    let update = try diff(from: baseline)
    return update.isEmpty ? nil : .updateServiceRecord(ref, gearItem: gearItem, update)
  }

  public func applying(_ operation: OutboxOperation) -> ServiceRecordFormValues {
    if case .updateServiceRecord(_, _, let update) = operation { applying(update) } else { self }
  }

  public static func delete(_ ref: RecordRef, gearItem: RecordRef) -> OutboxOperation {
    .deleteServiceRecord(ref, gearItem: gearItem)
  }
}

import Foundation

/// The rows and sentences of a gear item's service card (`GearServiceCard`): each schedule with
/// its status, due line and intervals, and each service logged, most recent first.
public enum GearServiceCardContent {
  public static let noSchedules =
    "No service schedule yet. Add one and you'll get a reminder before it's due — a regulator "
    + "service, a cylinder's visual inspection and hydro, a computer battery."
  public static let noRecords =
    "Nothing logged yet. Recording a service resets its schedule and keeps the receipt."

  /// One schedule's row.
  public struct ScheduleRow: Hashable, Sendable, Identifiable {
    public let id: UUID
    /// The kind, *Visual inspection*.
    public let kind: String
    public let label: String?
    public let isPaused: Bool
    /// The status badge at the title line's end and the due sentence under it; nil while paused,
    /// whose badge stands there instead.
    public let status: Badge?
    public let due: String?
    /// *Every 12 months or every 100 dives · last done Mar 4, 2026*.
    public let intervals: String
  }

  /// One logged service's row.
  public struct RecordRow: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let kind: String
    public let label: String?
    public let date: String
    /// Where, then who: *Blue Ocean · Ahmed*; nil where neither is known.
    public let servicedBy: String?
    public let notes: String?
  }

  public static func row(
    _ schedule: GearServiceScheduleRead, diveCount: Int, diveTime: Int, today: CalendarDate
  ) -> ScheduleRow {
    let arms = [
      schedule.intervalMonths.map { "Every \($0) months" },
      schedule.intervalDives.map { "every \($0) dives" },
      schedule.intervalHours.map { "every " + GearServiceText.countOf($0, .hour) },
    ].compactMap { $0 }
    let last =
      schedule.lastServiceOn.map {
        " · last done " + DateText.inSentence(DateText.date($0, relativeTo: today))
      } ?? " · never serviced"
    let active = schedule.isActive
    return ScheduleRow(
      id: schedule.uuid, kind: GearServiceKinds.label(schedule.kind), label: shown(schedule.label),
      isPaused: !active,
      status: active
        ? GearServiceStatus(schedule, diveCount: diveCount, diveTime: diveTime, today: today).badge
        : nil,
      due: active
        ? GearServiceText.due(schedule, diveCount: diveCount, diveTime: diveTime, today: today)
        : nil,
      intervals: arms.joined(separator: " or ") + last)
  }

  public static func row(_ record: GearServiceRecordRead, contacts: [ContactLookupItem])
    -> RecordRow
  {
    let date = DateText.date(record.servicedOn)
    let by = [
      RecordNames.contact(record.contactUuid, lookups: contacts), shown(record.performedBy),
    ]
    .compactMap { $0 }
    return RecordRow(
      id: record.uuid, kind: GearServiceKinds.label(record.kind), label: shown(record.label),
      date: date, servicedBy: by.isEmpty ? nil : by.joined(separator: " · "),
      notes: record.notes.isEmpty ? nil : record.notes)
  }

  /// Whether a schedule or a service for `gearItem` waits to be sent — a new one, or a change —
  /// which the card says, its rows showing the server's copy until it lands.
  public static func hasPendingWrite(_ items: [OutboxItem], gearItem: UUID) -> Bool {
    let ref = RecordRef.server(gearItem)
    return items.contains { item in
      guard !item.isFailed else { return false }
      switch item.operation {
      case .createServiceSchedule(let body): return body.gearItem == ref
      case .createServiceRecord(let body): return body.gearItem == ref
      case .updateServiceSchedule(_, let owner, _), .updateServiceRecord(_, let owner, _):
        return owner == ref
      default: return false
      }
    }
  }

  private static func shown(_ text: String?) -> String? {
    guard let text, !text.isEmpty else { return nil }
    return text
  }
}

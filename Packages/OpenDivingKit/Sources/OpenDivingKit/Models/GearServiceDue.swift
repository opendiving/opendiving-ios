/// When a servicing rule falls due, by each of its arms: what the service-status functions
/// read off a rule, whichever shape carried it.
public protocol GearServiceDue {
  var nextDueOn: CalendarDate? { get }
  /// A lifetime dive count.
  var nextDueAtDiveCount: Int? { get }
  /// A lifetime dive time, in seconds.
  var nextDueAtDiveTime: Int? { get }
  var isActive: Bool { get }
}

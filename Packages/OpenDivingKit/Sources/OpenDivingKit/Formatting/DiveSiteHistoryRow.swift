import Foundation

/// One entry of a Commons record's *History*, as the site's panel prints it and as the web's
/// card does: `Changed by Ann · Nov 16, 2026`, then each detail's label and its old and new
/// value in the diver's units. The pin is one detail, saying how far it moved.
public struct DiveSiteHistoryRow: Hashable, Sendable, Identifiable {
  public struct Detail: Hashable, Sendable {
    public var label: String
    /// `old → new`, or `Moved 12 m` for the pin.
    public var value: String
  }

  public static let title = "History"
  public static let notRecorded = DiveSiteProposalReview.notRecorded

  public let id: UUID
  /// The verb, then `by` and the name where one is shown.
  public var title: String
  public var date: String
  public var details: [Detail]

  /// `timeZone` is the day the entry is printed on, and `now` what it reads as `Today`
  /// against; the phone's own unless a test says.
  public init(
    _ entry: DiveSiteHistoryEntryRead, units: UnitSystem, in timeZone: TimeZone = .current,
    relativeTo now: Date? = Date()
  ) {
    id = entry.uuid
    let verb =
      switch entry.kind {
      case DiveSiteHistoryKind.added: "Added"
      case DiveSiteHistoryKind.changed: "Changed"
      default: entry.kind
      }
    title = entry.madeBy.flatMap { $0.isEmpty ? nil : verb + " by " + $0 } ?? verb
    date =
      entry.createdAt.instant.map { DateText.date($0, in: timeZone, relativeTo: now) }
      ?? DateText.diveDate(
        entry.createdAt, relativeTo: now.map { CalendarDate.today(in: timeZone, now: $0) })
    details = Self.details(entry.details, units: units)
  }

  private static let pin: Set<String> = ["latitude", "longitude"]

  private static func details(_ details: [DiveSiteHistoryDetail], units: UnitSystem) -> [Detail] {
    var lines: [Detail] = []
    var pinShown = false
    for detail in details {
      if pin.contains(detail.field) {
        guard !pinShown else { continue }
        pinShown = true
        lines.append(Detail(label: "Pin", value: moved(details, units: units)))
      } else if let member = members[detail.field] {
        lines.append(
          Detail(
            label: member.label,
            value: change(member.show(detail.old, units), member.show(detail.new, units))))
      } else {
        lines.append(
          Detail(label: detail.field, value: change(raw(detail.old), raw(detail.new))))
      }
    }
    return lines
  }

  /// How far the pin moved, or its old and new figures where either side has none.
  private static func moved(_ details: [DiveSiteHistoryDetail], units: UnitSystem) -> String {
    func side(_ value: (DiveSiteHistoryDetail) -> ImportChangeValue) -> (Double?, Double?) {
      let latitude = details.first { $0.field == "latitude" }.flatMap { value($0).number }
      let longitude = details.first { $0.field == "longitude" }.flatMap { value($0).number }
      return (latitude, longitude)
    }
    let before = side(\.old)
    let after = side(\.new)
    if let fromLatitude = before.0, let fromLongitude = before.1, let toLatitude = after.0,
      let toLongitude = after.1
    {
      let meters = GeoDistance.haversineMeters(
        fromLatitude: fromLatitude, longitude: fromLongitude, toLatitude: toLatitude,
        longitude: toLongitude)
      return "Moved " + GeoDistance.format(meters, units)
    }
    return change(
      CoordinateFormat.format(latitude: before.0, longitude: before.1),
      CoordinateFormat.format(latitude: after.0, longitude: after.1))
  }

  private static func change(_ before: String?, _ after: String?) -> String {
    func shown(_ text: String?) -> String {
      if let text, !text.isEmpty { text } else { notRecorded }
    }
    return shown(before) + " → " + shown(after)
  }

  /// A value this build has no words for, as the API sent it.
  private static func raw(_ value: ImportChangeValue) -> String? {
    value == .null ? nil : value.asSent
  }

  private struct Member: Sendable {
    let label: String
    /// Nil where the value records nothing.
    let show: @Sendable (ImportChangeValue, UnitSystem) -> String?
  }

  private static func text(_ value: ImportChangeValue, _: UnitSystem) -> String? {
    value == .null ? nil : value.text ?? value.asSent
  }

  private static func measured(_ format: @escaping @Sendable (Double, UnitSystem) -> String)
    -> @Sendable (ImportChangeValue, UnitSystem) -> String?
  {
    { value, units in value == .null ? nil : value.number.map { format($0, units) } ?? value.asSent
    }
  }

  private static func list(_ element: @escaping @Sendable (ImportChangeValue) -> String)
    -> @Sendable (ImportChangeValue, UnitSystem) -> String?
  {
    { value, _ in
      guard case .array(let items) = value else { return value == .null ? nil : value.asSent }
      return items.map(element).joined(separator: ", ")
    }
  }

  private static func worded(_ label: @escaping @Sendable (String) -> String)
    -> @Sendable (ImportChangeValue) -> String
  {
    { value in value.text.map(label) ?? value.asSent }
  }

  /// The shared members a pin's coordinates aside, in the words the propose flow's review uses.
  private static let members: [String: Member] = [
    "name": Member(label: "Name", show: text),
    "other_names": Member(label: "Other names", show: list { $0.text ?? $0.asSent }),
    "location_name": Member(label: "Location", show: text),
    "external_ids": Member(
      label: "Registries",
      show: list { entry in
        guard let registry = entry["registry"].text, let identifier = entry["identifier"].text
        else { return entry.asSent }
        return ExternalIdRegistry.label(registry) + " " + identifier
      }),
    "depth_from": Member(label: "Depth from", show: measured { UnitFormat.depth($0, $1) }),
    "depth_to": Member(label: "Depth to", show: measured { UnitFormat.depth($0, $1) }),
    "water_type": Member(
      label: "Water type",
      show: { value, _ in value == .null ? nil : worded(VocabularyLabels.waterType)(value) }),
    "altitude": Member(label: "Altitude", show: measured { UnitFormat.altitude($0, $1) }),
    "entry_types": Member(
      label: "Entry types", show: list(worded(VocabularyLabels.entryType))),
  ]
}

/// A schedule the new schedule's form starts from, by the gear's type
/// (`defaultSchedulesForGearType`). Common starting points, not a maker's or a law's interval:
/// every field stays the diver's to change.
public struct ServiceSchedulePreset: Hashable, Sendable {
  public let kind: String
  public let intervalMonths: Int?
  public let intervalDives: Int?

  public init(kind: String, intervalMonths: Int? = nil, intervalDives: Int? = nil) {
    self.kind = kind
    self.intervalMonths = intervalMonths
    self.intervalDives = intervalDives
  }

  static let byGearType: [String: [ServiceSchedulePreset]] = [
    "regulator": [Self(kind: "service", intervalMonths: 12, intervalDives: 100)],
    "bcd": [Self(kind: "service", intervalMonths: 12)],
    "wing": [Self(kind: "service", intervalMonths: 12)],
    "vest": [Self(kind: "service", intervalMonths: 12)],
    "cylinder": [
      Self(kind: "visual_inspection", intervalMonths: 12),
      Self(kind: "hydrostatic_test", intervalMonths: 60),
    ],
    "computer": [Self(kind: "battery", intervalMonths: 24)],
    "light": [Self(kind: "battery", intervalMonths: 24)],
    "drysuit": [Self(kind: "service", intervalMonths: 24)],
  ]

  /// The suggestions for a gear type, none for a type without a convention or no type.
  public static func defaults(forGearType type: String?) -> [ServiceSchedulePreset] {
    guard let type else { return [] }
    return byGearType[type] ?? []
  }
}

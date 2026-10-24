/// A cylinder volume the Volume box offers to pick: litres, which is what is stored in both unit
/// systems — a cylinder's cubic feet are the gas it holds at a working pressure the tank does
/// not record, so no factor converts one to the other.
public struct VolumePreset: Hashable, Sendable {
  public let liters: Double
  /// `11.1 L (AL80)`.
  public let label: String
  /// The cubic-feet name a US cylinder is known by, material and all: `AL80`, `HP100`.
  public let imperialName: String?

  init(_ liters: Double, _ label: String, _ imperialName: String? = nil) {
    self.liters = liters
    self.label = label
    self.imperialName = imperialName
  }

  /// How the preset reads to a diver in `units`: imperial leads with the cu-ft name where there
  /// is one, `AL80 (11.1 L)`.
  public func label(_ units: UnitSystem) -> String {
    guard units == .imperial, let imperialName else { return label }
    return "\(imperialName) (\(NumberText.plain(liters)) L)"
  }
}

/// One heading of presets in the Volume box.
public struct VolumePresetGroup: Hashable, Sendable {
  public let title: String
  /// Whose divers the group is for, which decides only where it sits; nil for neither.
  public let units: UnitSystem?
  public let presets: [VolumePreset]
}

/// The Volume box's presets, the web's lists at its pin: every group to every diver, the
/// reader's own family first, never filtered — a list hiding the unfamiliar half fails the
/// diver handed an AL80 on a boat in Florida.
public enum VolumePresets {
  public static let groups: [VolumePresetGroup] = [
    VolumePresetGroup(
      title: "Metric singles", units: .metric,
      presets: [
        VolumePreset(3, "3 L"), VolumePreset(5, "5 L"), VolumePreset(7, "7 L"),
        VolumePreset(10, "10 L"), VolumePreset(12, "12 L"), VolumePreset(15, "15 L"),
        VolumePreset(18, "18 L"), VolumePreset(20, "20 L"),
      ]),
    VolumePresetGroup(
      title: "Twin sets", units: nil,
      presets: [
        VolumePreset(14, "14 L (2x7 L)"), VolumePreset(22.2, "22.2 L (2x AL80)", "2x AL80"),
        VolumePreset(24, "24 L (2x12 L)"), VolumePreset(30, "30 L (2x15 L)"),
      ]),
    VolumePresetGroup(
      title: "US aluminium", units: .imperial,
      presets: [
        VolumePreset(5.7, "5.7 L (AL40)", "AL40"), VolumePreset(7.1, "7.1 L (AL50)", "AL50"),
        VolumePreset(9, "9 L (AL63)", "AL63"), VolumePreset(10, "10 L (AL72)", "AL72"),
        VolumePreset(11.1, "11.1 L (AL80)", "AL80"),
        VolumePreset(13.2, "13.2 L (AL100)", "AL100"),
      ]),
    VolumePresetGroup(
      title: "US steel", units: .imperial,
      presets: [
        VolumePreset(10.2, "10.2 L (HP80)", "HP80"), VolumePreset(12.9, "12.9 L (HP100)", "HP100"),
        VolumePreset(15, "15 L (HP117)", "HP117"), VolumePreset(15.3, "15.3 L (HP120)", "HP120"),
        VolumePreset(16, "16 L (HP130)", "HP130"), VolumePreset(13, "13 L (LP85)", "LP85"),
        VolumePreset(15, "15 L (LP95)", "LP95"), VolumePreset(17, "17 L (LP108)", "LP108"),
        VolumePreset(19, "19 L (LP121)", "LP121"),
      ]),
  ]

  /// The groups in the order a diver reading in `units` sees them, after a *Recently used*
  /// group of the diver's own volumes (`GET /dives/recent-volumes`) when there are any.
  public static func groups(for units: UnitSystem, recent: [Double] = []) -> [VolumePresetGroup] {
    let families = groups.filter { $0.units != nil }
    let recentGroup =
      recent.isEmpty
      ? []
      : [
        VolumePresetGroup(
          title: "Recently used", units: nil,
          presets: recent.map { VolumePreset($0, "\(NumberText.plain($0)) L") })
      ]
    return recentGroup + families.filter { $0.units == units }
      + families.filter { $0.units != units } + groups.filter { $0.units == nil }
  }

  /// Whether a volume is one of the twin-set totals — the only way a tank says it is a twin set.
  public static func isTwinSet(_ liters: Double?) -> Bool {
    groups[1].presets.contains { $0.liters == liters }
  }
}

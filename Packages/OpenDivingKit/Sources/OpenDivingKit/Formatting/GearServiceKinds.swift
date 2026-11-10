/// What kind of servicing a schedule or a service is about, in the API's order, which is the
/// pickers' (`SERVICE_KINDS`), and how each reads.
public enum GearServiceKinds {
  public static let all = [
    "service", "visual_inspection", "hydrostatic_test", "battery", "oxygen_clean", "other",
  ]

  static let labels = [
    "service": "Service",
    "visual_inspection": "Visual inspection",
    "hydrostatic_test": "Hydrostatic test",
    "battery": "Battery",
    "oxygen_clean": "Oxygen cleaning",
    "other": "Other",
  ]

  /// *Visual inspection*; a key this build does not know, de-snaked (`serviceKindLabel`).
  public static func label(_ kind: String) -> String {
    VocabularyLabels.labelOrFallback(labels, kind)
  }

  /// The kind, and the free-text label after it in brackets where there is one: the pair the
  /// API keys a schedule by, and what names a row's controls (`serviceKindAndLabel`).
  public static func kindAndLabel(kind: String, label: String?) -> String {
    let kind = self.label(kind)
    guard let label, !label.isEmpty else { return kind }
    return "\(kind) (\(label))"
  }

  /// The picker's keys: the vocabulary, and `current` after it where the API sent one this
  /// build does not know, so the form still shows what the record holds.
  public static func options(including current: String) -> [String] {
    all.contains(current) ? all : all + [current]
  }
}

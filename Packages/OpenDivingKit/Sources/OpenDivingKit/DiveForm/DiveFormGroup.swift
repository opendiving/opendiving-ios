/// The dive form's sections, in the order the web's form renders them (`DIVE_FORM_FIELD_GROUPS`).
public enum DiveFormGroup: String, CaseIterable, Sendable, Hashable {
  case importFiles = "Import"
  case training = "Training"
  case location = "Location"
  case people = "People"
  case diveInfo = "Dive info"
  case environment = "Environment"
  case tanks = "Tanks"
  case gear = "Gear"
  case marineLife = "Marine life"
  case notes = "Notes"

  /// The section's heading.
  public var title: String { rawValue }

  /// The hideable fields the section holds, in form order.
  public var fields: [DiveFormField] {
    DiveFormField.allCases.filter { $0.group == self }
  }

  /// Whether the web's form renders the section: *Dive info* always, for its start, number and
  /// time; *Tanks* while `mixtures` is visible, the per-tank columns being columns of its cards;
  /// any other while one of its fields is shown.
  public func isShown(_ visibility: DiveFormVisibility, values: DiveFormValues) -> Bool {
    switch self {
    case .diveInfo: true
    case .tanks: visibility.isVisible(.mixtures)
    default: fields.contains { visibility.shows($0, in: values) }
    }
  }
}

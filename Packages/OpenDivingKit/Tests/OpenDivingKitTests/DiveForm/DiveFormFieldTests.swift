import OpenDivingKit
import Testing

/// The registry against the web's: `src/lib/dive-form-fields.ts` at `opendiving-web`
/// `d5b2d545` — `DIVE_FORM_FIELDS` (27-61), `DIVE_FORM_FIELD_GROUPS` (162-173),
/// `DIVE_FORM_FIELD_REGISTRY` (188-235) and `DIVE_FORM_ALWAYS_ON_FIELDS` (246-257), copied
/// from the file rather than from the enum, so a key added on one side alone fails here.
struct DiveFormFieldTests {
  static let web: [(key: String, label: String, group: String)] = [
    ("file_import", "Upload dive files", "Import"),
    ("course_uuid", "Course", "Training"),
    ("trip_uuid", "Trip", "Location"),
    ("contact_uuid", "Dive center", "Location"),
    ("dive_site_uuids", "Dive site(s)", "Location"),
    ("entry_type", "Entry type", "Location"),
    ("boat_name", "Boat name", "Location"),
    ("people", "People", "People"),
    ("type", "Dive type", "Dive info"),
    ("max_depth", "Maximum depth", "Dive info"),
    ("avg_depth", "Average depth", "Dive info"),
    ("bottom_temperature", "Bottom temperature", "Environment"),
    ("visibility", "Visibility", "Environment"),
    ("water_type", "Water type", "Environment"),
    ("altitude", "Altitude", "Environment"),
    ("waves", "Waves", "Environment"),
    ("current", "Current", "Environment"),
    ("weather", "Weather", "Environment"),
    ("air_temperature", "Air temperature", "Environment"),
    ("mixtures", "Tanks", "Tanks"),
    ("gear_item_uuids", "Gear", "Gear"),
    ("weight", "Weight", "Gear"),
    ("sightings", "Species spotted", "Marine life"),
    ("rating", "Rating", "Notes"),
    ("tags", "Tags", "Notes"),
    ("notes", "Notes", "Notes"),
    ("mixture.gear_item_uuid", "Cylinder", "Tanks"),
    ("mixture.po2_limit", "ppO₂ limit", "Tanks"),
    ("mixture.helium", "He", "Tanks"),
    ("mixture.start_pressure", "Start pressure", "Tanks"),
    ("mixture.end_pressure", "End pressure", "Tanks"),
    ("mixture.usage", "Usage", "Tanks"),
    ("mixture.role", "Role", "Tanks"),
  ]

  @Test func theKeysAreTheWebsInItsOrder() {
    #expect(DiveFormField.allCases.map(\.rawValue) == Self.web.map(\.key))
  }

  @Test func eachKeyHasTheWebsLabelAndSection() {
    for (field, row) in zip(DiveFormField.allCases, Self.web) {
      #expect(field.label == row.label, "\(row.key)")
      #expect(field.group.title == row.group, "\(row.key)")
    }
  }

  @Test func theSectionsAreTheWebsInItsOrder() {
    #expect(
      DiveFormGroup.allCases.map(\.title) == [
        "Import", "Training", "Location", "People", "Dive info", "Environment", "Tanks", "Gear",
        "Marine life", "Notes",
      ])
  }

  @Test func theAlwaysShownInputs() {
    #expect(
      DiveFormField.alwaysShown.map(\.label) == [
        "Start time", "Dive number", "Dive time", "Volume", "O₂",
      ])
    #expect(
      DiveFormField.alwaysShown.map(\.group) == [.diveInfo, .diveInfo, .diveInfo, .tanks, .tanks])
  }

  /// dive-form-fields.test.ts:204-214, and a key a newer build stores is passed over.
  @Test func aStoredSetIsCanonical() {
    #expect(
      DiveFormField.canonical([
        "notes", "altitude", "notes", "mixture.role", "trip_uuid", "future_key",
      ])
        == [.trip, .altitude, .notes, .mixtureRole])
  }

  @Test func theMixtureColumnsAreTheMixtureKeys() {
    #expect(
      DiveFormField.allCases.filter(\.isMixtureColumn) == [
        .mixtureCylinder, .mixturePo2Limit, .mixtureHelium, .mixtureStartPressure,
        .mixtureEndPressure, .mixtureUsage, .mixtureRole,
      ])
  }

  /// The phone's one deliberate difference: files come in through the import screens.
  @Test func importIsNeverVisibleOnThePhone() {
    #expect(!DiveFormVisibility(hiddenKeys: []).isVisible(.fileImport))
    #expect(!DiveFormField.fileImport.holdsValue)
  }
}

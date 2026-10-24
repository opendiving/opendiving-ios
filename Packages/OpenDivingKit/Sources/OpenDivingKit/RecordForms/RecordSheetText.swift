/// The record sheets' pick-list labels the web's dialogs show (`CONTACT_ROLE_LABELS`,
/// `COURSE_STATUS_LABELS`, `CYLINDER_MATERIAL_LABELS`); an unknown key as written.
public enum RecordSheetText {
  public static func contactRole(_ value: String) -> String {
    VocabularyLabels.labelOrFallback(contactRoles, value)
  }

  public static func courseStatus(_ value: String) -> String {
    VocabularyLabels.labelOrFallback(courseStatuses, value)
  }

  public static func cylinderMaterial(_ value: String) -> String {
    VocabularyLabels.labelOrFallback(cylinderMaterials, value)
  }

  static let contactRoles = [
    "dive_center": "Dive center", "school": "School", "shop": "Shop",
    "accommodation": "Accommodation", "liveaboard": "Liveaboard", "club": "Club",
    "other": "Other",
  ]

  static let courseStatuses = [
    "planned": "Planned", "in_progress": "In progress", "completed": "Completed",
    "incomplete": "Incomplete", "provisional": "Provisional", "not_passed": "Not passed",
  ]

  static let cylinderMaterials = ["steel": "Steel", "aluminium": "Aluminium", "carbon": "Carbon"]
}

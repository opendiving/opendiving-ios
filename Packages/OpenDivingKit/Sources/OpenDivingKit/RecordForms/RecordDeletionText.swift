/// What each record's delete says before it happens, the web's.
public enum RecordDeletionText {
  public static let dive =
    "Are you sure you want to delete this dive? Its recordings and any dive-computer files you "
    + "imported are permanently deleted too — download anything you want to keep first."
  public static let trip =
    "Deleting removes this trip from every dive logged on it. The dives themselves are not touched."
  public static let diveSite =
    "Deleting removes this site from every dive logged here. The dives themselves are not touched."
  public static let commonsSite =
    "The site stays in OpenDiving Commons. Your notes and tags on it go, and your dives there no "
    + "longer name it. The dives themselves are not touched."
  public static let person =
    "Are you sure you want to delete this person? The dives, trips and courses they were on keep "
    + "everything else, but will no longer name them, and the certifications they signed will "
    + "name no instructor."
  public static let contact =
    "Are you sure you want to delete this contact? The dives, courses, certifications, service "
    + "records and trip parts that name it keep everything else, but will no longer name it."
  public static let course =
    "Are you sure you want to delete this course? The dives and certifications on it are kept, "
    + "but they will no longer name it."
  public static let gearItem =
    "Deleting removes this gear from your dives and gear sets. To keep it in your log and its "
    + "service history, archive it instead. Either way, its service reminders stop."
  public static let gearSet =
    "Are you sure you want to delete this gear set? The gear in it, and the dives it was used on, "
    + "are not affected."
  public static let certification =
    "Are you sure you want to delete this certification? The card images stored with it are "
    + "permanently deleted too."
  public static let serviceSchedule =
    "This stops the reminder. The services you've already logged stay in the history."
  public static let serviceRecord =
    "The schedule falls back to the service before this one, or to its in-service date if this "
    + "was the only one."

  /// What archiving a piece of gear says before it happens.
  public static func archiveGearItem(_ item: GearItemRead) -> String {
    let label = DiveDetailText.gearItemLabel(name: item.name, brand: item.brand)
    let dives = DiveDetailText.countNoun(item.diveCount, "dive")
    return "\"\(label)\" will stay on the \(dives) it's already logged on, but won't be offered "
      + "when logging new ones."
  }
}

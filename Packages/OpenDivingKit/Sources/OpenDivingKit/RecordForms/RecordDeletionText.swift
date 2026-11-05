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
}

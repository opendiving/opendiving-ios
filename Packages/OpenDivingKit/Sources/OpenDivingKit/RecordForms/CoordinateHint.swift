/// The line under a form's coordinates, which sends the reader to a map only where there is one.
public enum CoordinateHint {
  private static let paste = "Paste a “27.8506, 34.3136” pair into either field to fill both"

  public static func diveSite(hasMap: Bool) -> String {
    paste + (hasMap ? ", or place the site on the map below." : ".")
  }

  public static func contact(hasMap: Bool) -> String {
    paste + (hasMap ? ", or place the contact on the map." : ".")
  }

  /// *Search location*'s, where the site is being found rather than filled in.
  public static func searchedSite(hasMap: Bool) -> String {
    "Coordinates of the site" + (hasMap ? ", or place it on the map below." : ".")
  }
}

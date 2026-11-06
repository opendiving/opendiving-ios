/// The line under a form's coordinates, which sends the reader to a map only where there is one.
public enum CoordinateHint {
  private static let paste = "Paste a “27.8506, 34.3136” pair into either field to fill both"

  /// The site's boxes, which the map under them only shows.
  public static let diveSite = paste + "."

  public static func contact(hasMap: Bool) -> String {
    paste + (hasMap ? ", or place the contact on the map." : ".")
  }
}

/// What a dive is called wherever one is named.
public enum DiveTitles {
  /// The dive's sites as its primary site's name and `+N` for the rest, or `-` with none.
  /// A site's name is never blank, so nothing is dropped — unlike a trip's places.
  public static func sitesLabel(_ siteNames: [String]) -> String {
    guard let primary = siteNames.first else { return "-" }
    return siteNames.count > 1 ? "\(primary) +\(siteNames.count - 1)" : primary
  }

  /// `#212 Blue Hole +1`, or `Dive #212` for a dive with no site: a bare `#212` names
  /// nothing on its own.
  public static func title(number: Int, siteNames: [String]) -> String {
    siteNames.isEmpty ? "Dive #\(number)" : "#\(number) " + sitesLabel(siteNames)
  }
}

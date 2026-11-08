/// What the site finder says.
public enum SiteFinderText {
  /// The dive form's sheet: decision 10's *Find a dive site*, in the phone's title case.
  public static let diveFormTitle = "Find a Dive Site"
  public static let searchPrompt = "Search sites and places"
  public static let yoursLabel = "Your sites"
  public static let searchThisArea = "Search this area"
  public static let useMyLocation = "Use my location"
  public static let locating = "Finding your location"

  /// Why *Use my location* did not move the map.
  public static func locationFailure(_ failure: LocationFailure) -> String {
    switch failure {
    case .denied: "OpenDiving may not use your location. You can allow it in Settings."
    case .unavailable: "Your location could not be found."
    }
  }

  /// The line in place of a list that failed.
  public static func failure(_ error: APIError) -> String {
    error.isUnreachable
      ? "The server could not be reached, so nothing could be searched." : error.message
  }

  /// The line in place of an empty list.
  public static func empty(typed: Bool, yours: Bool) -> String {
    switch (typed, yours) {
    case (true, _): "No dive sites or places match."
    case (false, true): "No dive sites yet."
    case (false, false): "No dive sites here yet."
    }
  }
}

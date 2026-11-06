import Foundation

/// The credit a map owes, as the app shows it.
public enum MapAttribution {
  /// The instance's markdown credit with its sources set apart by © rather than a slash. Spaced,
  /// so the slashes of the links' addresses stay.
  public static func display(_ credit: String) -> String {
    credit.replacingOccurrences(of: " / ", with: " © ")
  }
}

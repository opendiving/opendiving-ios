/// The account's two pictures. The avatar is whatever the diver shows the app; the portrait is an
/// identification photo, shown on the check-in sheet and nowhere else. The raw value is the
/// route's: `/user/avatar`, `/user/portrait`.
public enum PictureKind: String, Hashable, Sendable, CaseIterable {
  case avatar, portrait

  /// Width to height. 7:9 is 35 by 45 mm, the passport photo's proportion.
  public var ratio: (width: Int, height: Int) {
    switch self {
    case .avatar: (1, 1)
    case .portrait: (7, 9)
    }
  }

  public var aspect: Double { Double(ratio.width) / Double(ratio.height) }

  /// How the picture is named in a sentence.
  public var label: String {
    switch self {
    case .avatar: "profile picture"
    case .portrait: "portrait"
    }
  }

  public var heading: String {
    switch self {
    case .avatar: "Profile picture"
    case .portrait: "Portrait"
    }
  }

  /// What the slot says while nothing is pending.
  public var help: String {
    switch self {
    case .avatar:
      "Shown in the account menu. The photo you pick is kept without its location data, so its"
        + " crop can be adjusted later."
    case .portrait:
      "Your face, as on a passport photo, for a dive shop's desk: shown on your check-in page and"
        + " nowhere else. The photo you pick is kept without its location data."
    }
  }

  public static let cropTitle = "Adjust Your Photo"
  /// The web's *Use this crop*, cut to its verb: on a 375-point phone the full label leaves the
  /// title no room between it and *Cancel*.
  public static let cropConfirm = "Use"

  /// What the crop sheet asks of the diver.
  public var cropDescription: String {
    switch self {
    case .avatar:
      "Drag to move, pinch or use the slider to zoom. Only the circle is shown."
    case .portrait:
      "Drag to move, pinch or use the slider to zoom. Frame your head and shoulders, as for a"
        + " passport photo."
    }
  }

  /// What the form says when the picture did not save: after fields that did, or alone.
  public func notSaved(_ reason: String, afterFields fieldsSaved: Bool) -> String {
    fieldsSaved
      ? "Saved, but your \(label) did not. \(reason)"
      : "Your \(label) did not save. \(reason)"
  }
}

/// What saving the form will do to its picture. Nothing is sent when the diver chooses it: the
/// form holds the edit and sends it after its fields, so leaving the screen leaves the stored
/// picture as it was.
public enum PictureEdit: Hashable, Sendable {
  /// A new photo, kept as the original under `filename`.
  case replace(PictureSource, filename: String, type: PictureFileType, crop: PictureCrop)
  /// A new crop over the original the server already holds, sent without it.
  case adjust(PictureSource, crop: PictureCrop)
  /// The portrait's only: the profile picture's original, at a crop of its own.
  case copy(PictureSource, crop: PictureCrop)
  case remove

  /// What a crop over the edit's picture is chosen on; nil for a removal.
  public var source: PictureSource? {
    switch self {
    case .replace(let source, _, _, _), .adjust(let source, _), .copy(let source, _): source
    case .remove: nil
    }
  }

  public var crop: PictureCrop? {
    switch self {
    case .replace(_, _, _, let crop), .adjust(_, let crop), .copy(_, let crop): crop
    case .remove: nil
    }
  }
}

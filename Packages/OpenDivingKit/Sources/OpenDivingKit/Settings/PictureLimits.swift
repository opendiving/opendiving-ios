/// The API's limits on a picture, mirrored so a photo it would refuse is refused at the pick,
/// before the form's fields have saved, and what the phone does to a pick to come inside them.
public enum PictureLimits {
  /// The upload ceiling (`MAX_PICTURE_UPLOAD_SIZE`).
  public static let maxUploadSize = 10 * 1024 * 1024
  /// What a JPEG may declare (`MAX_PICTURE_PIXELS`).
  public static let maxPicturePixels = 50_000_000
  /// What the API decodes whole, which for a PNG is every pixel (`MAX_ORIGINAL_DECODE_PIXELS`).
  /// A JPEG never meets it: the API decodes one reduced.
  public static let maxOriginalDecodePixels = 4032 * 3024
  /// The qualities a converted photo is tried at, best first, until one is under
  /// ``maxUploadSize``.
  public static let jpegQualities = [0.9, 0.8, 0.7, 0.6, 0.5]

  public static let tooLargeTitle = "That photo is too large"
  public static let tooLargeBytes = "Pick one under \(maxUploadSize / (1024 * 1024)) MB."
  public static let unreadable = "That file could not be read as an image."

  /// What the phone does to a pick before it is cropped.
  public enum Preparation: Hashable, Sendable {
    /// Sent as it was picked.
    case asPicked(PictureFileType)
    /// Converted to a JPEG at its own pixel dimensions, upright.
    case convert
    /// Refused, with why.
    case refuse(String)
  }

  /// Why the API would refuse a picture of this type and size, as the web's
  /// `pictureSizeProblem` says it; nil when it would not. `width` and `height` are the upright
  /// image's.
  public static func sizeProblem(_ type: PictureFileType, width: Int, height: Int) -> String? {
    let size = "\(width) × \(height)"
    switch type {
    case .png:
      return width * height > maxOriginalDecodePixels
        ? "A PNG can be at most 4032 × 3024 pixels, and this one is \(size). A JPEG of it will do."
        : nil
    case .jpeg:
      return width * height > maxPicturePixels
        ? "A JPEG can be at most 50 megapixels, and this one is \(size)." : nil
    }
  }

  /// What to do with a pick of `type` — nil for a format the API keeps no original of — and
  /// `byteCount` bytes, `width` by `height` upright. A JPEG or a PNG inside every limit goes as it
  /// is; anything else is converted, which brings the decode cap and, mostly, the file size
  /// inside; what not even a JPEG may be is refused.
  public static func preparation(
    for type: PictureFileType?, byteCount: Int, width: Int, height: Int
  ) -> Preparation {
    if let type, byteCount <= maxUploadSize, sizeProblem(type, width: width, height: height) == nil
    {
      return .asPicked(type)
    }
    if let problem = sizeProblem(.jpeg, width: width, height: height) {
      return .refuse(problem)
    }
    return .convert
  }

  /// Whether a converted photo of `byteCount` bytes can be sent.
  public static func fits(_ byteCount: Int) -> Bool { byteCount <= maxUploadSize }
}

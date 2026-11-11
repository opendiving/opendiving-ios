import OpenDivingKit
import UIKit

/// Makes a picked photo ready to send as one of the account's pictures, as
/// ``PictureLimits/preparation(for:byteCount:width:height:)`` decides: a JPEG or a PNG inside the
/// limits goes as it is, its orientation left for the server to apply as it renders; anything
/// else — a HEIC from the camera, a WebP — is redrawn upright and encoded as a JPEG at its own
/// pixel dimensions, so the crop measured on the upright picture is the crop of the bytes sent.
/// Pure work on bytes, run off the main actor.
nonisolated enum PicturePreparer {
  struct Prepared: Sendable {
    let source: PictureSource
    let filename: String
    let type: PictureFileType

    /// The crop a new picture is chosen on.
    var cropping: PictureCropping {
      PictureCropping(purpose: .replace(filename: filename, type: type), source: source)
    }
  }

  static func prepare(_ data: Data, kind: PictureKind) -> Result<Prepared, PictureRefusal> {
    guard let image = UIImage(data: data) else { return .failure(.unreadable) }
    // `UIImage` reports its size with the file's orientation applied: the upright size.
    let (width, height) = pixels(of: image)
    switch PictureLimits.preparation(
      for: PictureFileType(sniffing: data), byteCount: data.count, width: width, height: height)
    {
    case .asPicked(let type):
      return .success(
        Prepared(
          source: PictureSource(data: data, width: width, height: height),
          filename: "\(kind.rawValue).\(type.fileExtension)", type: type))
    case .convert:
      return converted(image, kind: kind)
    case .refuse(let problem):
      return .failure(.tooLarge(problem))
    }
  }

  /// A photograph the camera hands over already decoded, which is always encoded.
  static func prepare(_ image: UIImage, kind: PictureKind) -> Result<Prepared, PictureRefusal> {
    let (width, height) = pixels(of: image)
    if let problem = PictureLimits.sizeProblem(.jpeg, width: width, height: height) {
      return .failure(.tooLarge(problem))
    }
    return converted(image, kind: kind)
  }

  private static func pixels(of image: UIImage) -> (width: Int, height: Int) {
    (
      Int((image.size.width * image.scale).rounded()),
      Int((image.size.height * image.scale).rounded())
    )
  }

  /// `image` drawn upright onto white, the paper a transparent picture prints on, in sRGB, which
  /// is what the server's renderer assumes, and encoded at the best quality that fits.
  private static func converted(_ image: UIImage, kind: PictureKind)
    -> Result<Prepared, PictureRefusal>
  {
    let (width, height) = pixels(of: image)
    guard width > 0, height > 0 else { return .failure(.unreadable) }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    format.preferredRange = .standard
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    let upright = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
      UIColor.white.setFill()
      context.fill(bounds)
      image.draw(in: bounds)
    }
    for quality in PictureLimits.jpegQualities {
      guard let data = upright.jpegData(compressionQuality: quality) else {
        return .failure(.unreadable)
      }
      if PictureLimits.fits(data.count) {
        return .success(
          Prepared(
            source: PictureSource(data: data, width: width, height: height),
            filename: "\(kind.rawValue).jpg", type: .jpeg))
      }
    }
    return .failure(.tooLarge)
  }
}

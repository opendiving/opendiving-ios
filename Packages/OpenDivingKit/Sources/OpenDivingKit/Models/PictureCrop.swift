/// Where a picture was cropped from its original, in the upright original's pixels.
public struct PictureCrop: Codable, Hashable, Sendable {
  public let x: Int
  public let y: Int
  public let width: Int
  public let height: Int

  public init(x: Int, y: Int, width: Int, height: Int) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  /// `area` as the API takes it, as the web's `toPictureCrop` makes it: whole pixels, inside an
  /// upright image `imageWidth` by `imageHeight`, and at `kind`'s ratio to within the pixel the
  /// API allows. A rectangle a pixel over an edge or off the ratio is a 422 after the form's
  /// fields have saved, so none is sent. The height leads and the width follows it at the ratio,
  /// the pair shrinking a pixel at a time until it fits, centred on the rectangle it was given.
  public static func fitted(
    _ area: CropFrame.Area, imageWidth: Int, imageHeight: Int, kind: PictureKind
  ) -> PictureCrop {
    let (ratioWidth, ratioHeight) = (Double(kind.ratio.width), Double(kind.ratio.height))
    func following(_ height: Int) -> Int {
      max(1, Int(jsRound(Double(height) * ratioWidth / ratioHeight)))
    }
    var height = max(1, min(imageHeight, Int(jsRound(area.height))))
    var width = following(height)
    while width > imageWidth, height > 1 {
      height -= 1
      width = following(height)
    }
    let x = Int(jsRound(area.x + (area.width - Double(width)) / 2))
    let y = Int(jsRound(area.y + (area.height - Double(height)) / 2))
    return PictureCrop(
      x: min(max(0, x), imageWidth - width), y: min(max(0, y), imageHeight - height),
      width: width, height: height)
  }

  /// The crop as the frame a crop sheet opens on.
  public var area: CropFrame.Area {
    CropFrame.Area(x: Double(x), y: Double(y), width: Double(width), height: Double(height))
  }

  /// JavaScript's `Math.round`, half up, so the same rectangle comes out as the web's does.
  private static func jsRound(_ value: Double) -> Double {
    (value + 0.5).rounded(.down)
  }
}

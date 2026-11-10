/// Where a picked picture is framed to the card's shape before it is kept, as the web's crop
/// dialog frames it: at the least zoom the frame is the largest of the card's shape the picture
/// holds, zooming in narrows it about its centre, and the frame never leaves the picture.
/// Measured in the picture's own pixels.
public struct CertificationCardCrop: Hashable, Sendable {
  /// Width over height of every card: a current PADI e-card, 1013 by 638
  /// (`CERTIFICATION_CARD_ASPECT`).
  public static let aspect = 1013.0 / 638.0
  /// The widest a framed card is kept at (`CERTIFICATION_CARD_EXPORT_WIDTH`).
  public static let exportWidth = 1024.0
  public static let minZoom = 1.0
  public static let maxZoom = 3.0

  /// A rectangle in the picture's pixels.
  public struct Area: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
  }

  public let imageWidth: Double
  public let imageHeight: Double
  public private(set) var zoom = Self.minZoom
  /// The frame's centre.
  public private(set) var centerX: Double
  public private(set) var centerY: Double

  /// The frame centred on the picture, at the least zoom.
  public init(imageWidth: Double, imageHeight: Double) {
    self.imageWidth = imageWidth
    self.imageHeight = imageHeight
    centerX = imageWidth / 2
    centerY = imageHeight / 2
  }

  /// The part of the picture that is kept.
  public var area: Area {
    let (width, height) = size
    return Area(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
  }

  /// The kept card's pixels: the frame's width, but no wider than ``exportWidth``.
  public var exportSize: (width: Double, height: Double) {
    let width = min(size.width, Self.exportWidth).rounded()
    return (width, (width / Self.aspect).rounded())
  }

  /// Moves the frame to centre on `x`, `y`, as far as the picture allows.
  public mutating func center(x: Double, y: Double) {
    let (width, height) = size
    centerX = Self.clamp(x, width / 2, imageWidth - width / 2)
    centerY = Self.clamp(y, height / 2, imageHeight - height / 2)
  }

  /// Zooms about the frame's centre, between ``minZoom`` and ``maxZoom``.
  public mutating func setZoom(_ zoom: Double) {
    self.zoom = Self.clamp(zoom, Self.minZoom, Self.maxZoom)
    center(x: centerX, y: centerY)
  }

  private var size: (width: Double, height: Double) {
    let fitted =
      imageWidth / imageHeight > Self.aspect
      ? (width: imageHeight * Self.aspect, height: imageHeight)
      : (width: imageWidth, height: imageWidth / Self.aspect)
    return (fitted.width / zoom, fitted.height / zoom)
  }

  private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
    high < low ? (low + high) / 2 : min(max(value, low), high)
  }
}

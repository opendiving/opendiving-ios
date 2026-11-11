/// Where a picked picture is framed to the card's shape before it is kept, as the web's crop
/// dialog frames it: a ``CropFrame`` of the card's shape. Measured in the picture's own pixels.
public struct CertificationCardCrop: Hashable, Sendable {
  /// Width over height of every card: a current PADI e-card, 1013 by 638
  /// (`CERTIFICATION_CARD_ASPECT`).
  public static let aspect = 1013.0 / 638.0
  /// The widest a framed card is kept at (`CERTIFICATION_CARD_EXPORT_WIDTH`).
  public static let exportWidth = 1024.0
  public static let minZoom = CropFrame.minZoom
  public static let maxZoom = CropFrame.defaultMaxZoom

  public typealias Area = CropFrame.Area

  private var frame: CropFrame

  /// The frame centred on the picture, at the least zoom.
  public init(imageWidth: Double, imageHeight: Double) {
    frame = CropFrame(aspect: Self.aspect, imageWidth: imageWidth, imageHeight: imageHeight)
  }

  public var imageWidth: Double { frame.imageWidth }
  public var imageHeight: Double { frame.imageHeight }
  public var zoom: Double { frame.zoom }
  /// The frame's centre.
  public var centerX: Double { frame.centerX }
  public var centerY: Double { frame.centerY }

  /// The part of the picture that is kept.
  public var area: Area { frame.area }

  /// The kept card's pixels: the frame's width, but no wider than ``exportWidth``.
  public var exportSize: (width: Double, height: Double) {
    let width = min(frame.area.width, Self.exportWidth).rounded()
    return (width, (width / Self.aspect).rounded())
  }

  /// Moves the frame to centre on `x`, `y`, as far as the picture allows.
  public mutating func center(x: Double, y: Double) {
    frame.center(x: x, y: y)
  }

  /// Zooms about the frame's centre, between ``minZoom`` and ``maxZoom``.
  public mutating func setZoom(_ zoom: Double) {
    frame.setZoom(zoom)
  }
}

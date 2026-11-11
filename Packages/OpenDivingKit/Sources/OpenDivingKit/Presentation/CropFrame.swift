/// A frame of a fixed shape over a picture, as the web's crop dialog moves it: at the least
/// zoom the frame is the largest of its shape the picture holds, zooming in narrows it about its
/// centre, and the frame never leaves the picture. Measured in the picture's own pixels, upright.
public struct CropFrame: Hashable, Sendable {
  public static let minZoom = 1.0
  /// How far in a frame zooms, unless it opened further in than that.
  public static let defaultMaxZoom = 3.0

  /// A rectangle in the picture's pixels.
  public struct Area: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
      self.x = x
      self.y = y
      self.width = width
      self.height = height
    }
  }

  /// Width over height of the frame.
  public let aspect: Double
  public let imageWidth: Double
  public let imageHeight: Double
  public let maxZoom: Double
  public private(set) var zoom = Self.minZoom
  /// The frame's centre.
  public private(set) var centerX: Double
  public private(set) var centerY: Double

  /// The frame centred on the picture, at the least zoom.
  public init(aspect: Double, imageWidth: Double, imageHeight: Double) {
    self.aspect = aspect
    self.imageWidth = imageWidth
    self.imageHeight = imageHeight
    maxZoom = Self.defaultMaxZoom
    centerX = imageWidth / 2
    centerY = imageHeight / 2
  }

  /// The frame over `area` as nearly as the picture allows, for adjusting a crop chosen before.
  /// A crop narrower than the default zoom reaches still opens where it was.
  public init(aspect: Double, imageWidth: Double, imageHeight: Double, showing area: Area) {
    let fitted = Self.fitted(aspect: aspect, imageWidth, imageHeight).width
    let zoom = area.width > 0 ? max(Self.minZoom, fitted / area.width) : Self.minZoom
    self.aspect = aspect
    self.imageWidth = imageWidth
    self.imageHeight = imageHeight
    maxZoom = max(Self.defaultMaxZoom, zoom)
    self.zoom = zoom
    centerX = imageWidth / 2
    centerY = imageHeight / 2
    center(x: area.x + area.width / 2, y: area.y + area.height / 2)
  }

  /// The part of the picture that is kept.
  public var area: Area {
    let (width, height) = size
    return Area(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
  }

  /// Moves the frame to centre on `x`, `y`, as far as the picture allows.
  public mutating func center(x: Double, y: Double) {
    let (width, height) = size
    centerX = Self.clamp(x, width / 2, imageWidth - width / 2)
    centerY = Self.clamp(y, height / 2, imageHeight - height / 2)
  }

  /// Zooms about the frame's centre, between ``minZoom`` and ``maxZoom``.
  public mutating func setZoom(_ zoom: Double) {
    self.zoom = Self.clamp(zoom, Self.minZoom, maxZoom)
    center(x: centerX, y: centerY)
  }

  /// The frame's size at the least zoom.
  var fittedSize: (width: Double, height: Double) {
    Self.fitted(aspect: aspect, imageWidth, imageHeight)
  }

  private var size: (width: Double, height: Double) {
    let fitted = fittedSize
    return (fitted.width / zoom, fitted.height / zoom)
  }

  private static func fitted(aspect: Double, _ width: Double, _ height: Double)
    -> (width: Double, height: Double)
  {
    width / height > aspect ? (height * aspect, height) : (width, width / aspect)
  }

  private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
    high < low ? (low + high) / 2 : min(max(value, low), high)
  }
}

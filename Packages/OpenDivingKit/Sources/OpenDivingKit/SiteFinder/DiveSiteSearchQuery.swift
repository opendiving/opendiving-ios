import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// What one request of `GET /dive-sites/search` asks: the text typed, the camera, the view when
/// *Search this area* narrowed to it, and the filters.
///
/// Every coordinate leaves the phone rounded to two decimals, about a kilometre, whatever moved
/// the camera: the server keeps none, but its access logs hold the query string. The view is
/// rounded outward, so the rounded box still holds what was shown.
public struct DiveSiteSearchQuery: Hashable, Sendable {
  public var text: String
  public var camera: DeviceLocation?
  public var box: LatLonBounds?
  /// The dive being edited's start, so the sites a dive of its time named rank first; nil ranks
  /// as of now.
  public var until: DiveTimestamp?
  /// Only the diver's own sites and the Commons records they saved.
  public var yours: Bool

  public init(
    text: String = "", camera: DeviceLocation? = nil, box: LatLonBounds? = nil,
    until: DiveTimestamp? = nil, yours: Bool = false
  ) {
    self.text = text
    self.camera = camera
    self.box = box
    self.until = until
    self.yours = yours
  }

  /// The query string, rounded.
  var items: [URLQueryItem] {
    var items: [URLQueryItem] = []
    let typed = text.trimmedOfWhitespace
    if !typed.isEmpty { items.append(URLQueryItem(name: "q", value: typed)) }
    if let camera {
      items.append(URLQueryItem(name: "latitude", value: Self.text(Self.round(camera.latitude))))
      items.append(
        URLQueryItem(
          name: "longitude", value: Self.text(Self.round(Self.wrap(camera.longitude)))))
    }
    if let box {
      let sent = Self.rounded(box)
      items.append(URLQueryItem(name: "south", value: Self.text(sent.south)))
      items.append(URLQueryItem(name: "north", value: Self.text(sent.north)))
      items.append(URLQueryItem(name: "west", value: Self.text(sent.west)))
      items.append(URLQueryItem(name: "east", value: Self.text(sent.east)))
    }
    if let until { items.append(URLQueryItem(name: "until", value: until.wireValue)) }
    if yours { items.append(URLQueryItem(name: "yours", value: "true")) }
    return items
  }

  /// Hundredths of a degree.
  static let precision = 100.0

  static func round(_ degrees: Double) -> Double {
    (degrees * precision).rounded() / precision
  }

  /// The view's edges in −180…180, each rounded away from the middle; a view as wide as the world
  /// or wider is the world. A `west` past its `east` crosses the antimeridian, as the API reads it.
  static func rounded(_ box: LatLonBounds) -> LatLonBounds {
    let south = max(-90, outward(box.south, .down))
    let north = min(90, outward(box.north, .up))
    guard box.east - box.west < 360 else {
      return LatLonBounds(south: south, north: north, west: -180, east: 180)
    }
    // The east edge reads 180 rather than −180, so a view ending on the line does not cross it.
    var east = wrap(box.east)
    if east == -180 { east = 180 }
    return LatLonBounds(
      south: south, north: north, west: max(-180, outward(wrap(box.west), .down)),
      east: min(180, outward(east, .up)))
  }

  /// To hundredths in `direction`, from the degrees as written: the wrap's arithmetic leaves
  /// 183.1 as −176.8999…, which rounded up as it stands would gain a hundredth.
  private static func outward(_ degrees: Double, _ direction: FloatingPointRoundingRule)
    -> Double
  {
    let written = (degrees * precision * 1e6).rounded() / 1e6
    return written.rounded(direction) / precision
  }

  /// A longitude in −180…180, the world's copies the map scrolls to folded back.
  static func wrap(_ longitude: Double) -> Double {
    guard longitude < -180 || longitude > 180 else { return longitude }
    let folded = (longitude + 180).truncatingRemainder(dividingBy: 360)
    return (folded < 0 ? folded + 360 : folded) - 180
  }

  /// Exactly two decimals, whatever the locale: `28.57`, `-0.50`.
  static func text(_ degrees: Double) -> String {
    let hundredths = Int((degrees * precision).rounded())
    let whole = abs(hundredths) / 100
    let fraction = abs(hundredths) % 100
    return (hundredths < 0 ? "-" : "") + "\(whole)." + (fraction < 10 ? "0" : "") + "\(fraction)"
  }
}

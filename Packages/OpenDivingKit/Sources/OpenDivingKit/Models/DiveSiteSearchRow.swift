import Foundation

/// One row of `GET /dive-sites/search`, a site or a place, told apart by `kind`.
public enum DiveSiteSearchRow: Codable, Hashable, Sendable, Identifiable {
  case site(DiveSiteSearchItem)
  case place(PlaceSearchItem)

  static let siteKind = "site"
  static let placeKind = "place"

  enum CodingKeys: String, CodingKey {
    case kind
  }

  /// A row of a kind this build does not know, which the page leaves out.
  struct UnknownKind: Error {
    let kind: String
  }

  public var id: String {
    switch self {
    case .site(let item): "site:\(item.ref)"
    case .place(let item):
      "place:\(item.place.sourceId ?? "\(item.place.latitude),\(item.place.longitude)")"
        + ":\(item.place.location)"
    }
  }

  public var distanceM: Double? {
    switch self {
    case .site(let item): item.distanceM
    case .place(let item): item.distanceM
    }
  }

  public init(from decoder: any Decoder) throws {
    let kind = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .kind)
    switch kind {
    case Self.siteKind: self = .site(try DiveSiteSearchItem(from: decoder))
    case Self.placeKind: self = .place(try PlaceSearchItem(from: decoder))
    default: throw UnknownKind(kind: kind)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .site(let item):
      try c.encode(Self.siteKind, forKey: .kind)
      try item.encode(to: encoder)
    case .place(let item):
      try c.encode(Self.placeKind, forKey: .kind)
      try item.encode(to: encoder)
    }
  }
}

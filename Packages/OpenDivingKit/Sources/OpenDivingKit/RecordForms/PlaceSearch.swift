import Foundation

/// What a place search row is, by where it came from: a place to put a site in, or a Commons
/// record, which is a site already.
public enum PlacePick: Hashable, Sendable {
  case geocode(GeocodeResult)
  case commons(DiveSiteLookupItem)
}

/// One row of a place search's list.
public struct PlaceSearchRow: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  public let hint: String?
  public let pick: PlacePick
}

/// The rules the place searches share (`place-search.tsx`, `trip-parts-field.tsx`): the query
/// bounds, how a row reads, what a pick writes, and the coordinate text the forms hold.
public enum PlaceSearch {
  /// The narrowest bounds outside which neither source is asked.
  public static let minQueryLength = 2
  public static let maxQueryLength = 200
  /// How long typing pauses before a search goes out.
  public static let debounce: Duration = .milliseconds(450)
  /// The API's ceiling on a place's name.
  public static let maxLocationNameLength = 255

  /// The dive site search's two sources in one list, Commons records first, a geocoded row
  /// dropped where it is an OpenStreetMap object a listed record names.
  public static func siteRows(
    commons: [DiveSiteLookupItem], geocoded: [GeocodeResult], query: String = "",
    position: DeviceLocation?, units: UnitSystem
  ) -> [PlaceSearchRow] {
    var rows: [PlaceSearchRow] = []
    var seen: Set<String> = []
    for site in commons {
      let id = "commons:\(site.ref.uuid)"
      guard seen.insert(id).inserted else { continue }
      rows.append(
        PlaceSearchRow(
          id: id, name: site.name,
          hint: commonsHint(site, query: query, position: position, units: units),
          pick: .commons(site)))
    }
    for result in geocoded {
      let sameRecord = commons.contains { sameObject(result, as: $0) }
      guard !sameRecord else { continue }
      let id = "\(result.latitude):\(result.longitude):\(result.location)"
      guard seen.insert(id).inserted else { continue }
      let label = geocodeLabel(result)
      rows.append(
        PlaceSearchRow(id: id, name: label.name, hint: label.context, pick: .geocode(result)))
    }
    return rows
  }

  /// A trip part's search: geocoded places alone, each row reading exactly what a pick saves.
  public static func placeRows(_ geocoded: [GeocodeResult]) -> [PlaceSearchRow] {
    var rows: [PlaceSearchRow] = []
    var seen: Set<String> = []
    for result in geocoded {
      let location = location(of: result)
      let id = "\(location.latitude ?? 0):\(location.longitude ?? 0):\(location.name)"
      guard seen.insert(id).inserted else { continue }
      rows.append(PlaceSearchRow(id: id, name: location.name, hint: nil, pick: .geocode(result)))
    }
    return rows
  }

  /// Whether a geocoded row is an OpenStreetMap object the record names: the geocoder's id is
  /// spelled as that registry's.
  private static func sameObject(_ result: GeocodeResult, as site: DiveSiteLookupItem) -> Bool {
    guard result.source == geocoderOpenStreetMap, let id = result.sourceId else { return false }
    return site.externalIds.contains {
      $0.registry == ExternalIdRegistry.openStreetMap.rawValue && $0.identifier == id
    }
  }

  private static let geocoderOpenStreetMap = "osm"

  /// What a Commons row says besides its name: another name, the one `query` found it by where
  /// the name itself does not hold it, where it is, and how far from the position the form has.
  public static func commonsHint(
    _ site: DiveSiteLookupItem, query: String = "", position: DeviceLocation?, units: UnitSystem
  ) -> String? {
    var parts: [String] = []
    if let name = otherName(of: site, query: query) { parts.append(name) }
    if let place = site.location?.name.trimmedOfWhitespace, !place.isEmpty { parts.append(place) }
    if let position, let latitude = site.latitude, let longitude = site.longitude {
      let meters = GeoDistance.haversineMeters(
        fromLatitude: position.latitude, longitude: position.longitude,
        toLatitude: latitude, longitude: longitude)
      parts.append(GeoDistance.format(meters, units))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private static func otherName(of site: DiveSiteLookupItem, query: String) -> String? {
    let names = site.otherNames.map(\.trimmedOfWhitespace).filter {
      !$0.isEmpty && $0 != site.name.trimmedOfWhitespace
    }
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    let needle = query.trimmedOfWhitespace
    guard !needle.isEmpty, site.name.range(of: needle, options: options) == nil else {
      return names.first
    }
    return names.first { $0.range(of: needle, options: options) != nil } ?? names.first
  }

  /// `region, country`, whichever are known (`formatPlaceContext`).
  public static func placeContext(region: String?, country: String?) -> String? {
    let parts = [region, country].compactMap { $0 }.filter { !$0.trimmedOfWhitespace.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }

  /// A geocoded row: the place's own name and where it is, a context part the name already
  /// says left out; a result with no name of its own reads as its whole location
  /// (`geocodeResultLabel`).
  public static func geocodeLabel(_ result: GeocodeResult) -> (name: String, context: String?) {
    guard let name = result.name else { return (result.location, nil) }
    let region = unrepeated(result.region, [name])
    let country = unrepeated(result.country, [name, region])
    return (name, placeContext(region: region, country: country))
  }

  static func unrepeated(_ part: String?, _ labels: [String?]) -> String? {
    guard let trimmed = part?.trimmedOfWhitespace, !trimmed.isEmpty else { return nil }
    let said = labels.flatMap { label in
      (label ?? "").split(separator: ",").map { $0.trimmedOfWhitespace.lowercased() }
    }
    return said.contains(trimmed.lowercased()) ? nil : trimmed
  }

  /// The whole place a geocoded pick saves: its name, centre and bounds.
  public static func location(of result: GeocodeResult) -> LocationWrite {
    LocationWrite(
      name: result.location, latitude: result.latitude, longitude: result.longitude,
      bboxSouth: result.bboxSouth, bboxNorth: result.bboxNorth, bboxWest: result.bboxWest,
      bboxEast: result.bboxEast)
  }

  /// A typed place: its name alone, cut to the API's ceiling; nil for a blank box.
  public static func typedLocation(_ text: String) -> LocationWrite? {
    let trimmed = text.trimmedOfWhitespace
    guard !trimmed.isEmpty else { return nil }
    return LocationWrite(name: String(trimmed.prefix(maxLocationNameLength)))
  }

  /// What the location looks like after the place at a newly placed position was looked up
  /// (`useGeocodedLocation`): the place's name and its credit; cleared where the position has
  /// no name and a name was there; nil — leave everything — where nothing was learned.
  public static func adopting(_ outcome: ReverseGeocode, current: LocationWrite?)
    -> (location: LocationWrite?, credit: String?)?
  {
    switch outcome {
    case .named(let result): return (LocationWrite(name: result.location), result.attribution)
    case .nameless:
      guard let name = current?.name, !name.trimmedOfWhitespace.isEmpty else { return nil }
      return (nil, nil)
    case .unknown: return nil
    }
  }

  /// The position two boxes hold, when both read as coordinates in range: what the map pins
  /// and the Commons search sorts by (`parseFormPosition`).
  public static func position(latitude: String, longitude: String) -> DeviceLocation? {
    guard let latitude = CoordinateEntry.value(latitude), abs(latitude) <= 90,
      let longitude = CoordinateEntry.value(longitude), abs(longitude) <= 180
    else { return nil }
    return DeviceLocation(latitude: latitude, longitude: longitude)
  }

  /// A coordinate as the form's text: the shortest decimal that reads back as it, empty for
  /// none (`formatCoordinateForForm`).
  public static func coordinateText(_ value: Double?) -> String {
    value.map(NumberText.plain) ?? ""
  }

  /// A pasted `27.8506, 34.3136` as the two boxes' text: separated by a comma, a semicolon or
  /// white space. A bare comma between two integers is a European decimal, not a pair
  /// (`parseCoordinatePair`).
  public static func coordinatePair(_ text: String) -> (latitude: String, longitude: String)? {
    let trimmed = text.trimmedOfWhitespace
    if isDecimalComma(trimmed) { return nil }
    var rest = Substring(trimmed)
    guard let latitude = number(&rest) else { return nil }
    let before = rest.count
    rest = rest.drop(while: \.isWhitespace)
    let spaced = rest.count < before
    if let first = rest.first, first == "," || first == ";" {
      rest = rest.dropFirst().drop(while: \.isWhitespace)
    } else if !spaced {
      return nil
    }
    guard let longitude = number(&rest), rest.allSatisfy(\.isWhitespace) else { return nil }
    return (latitude, longitude)
  }

  /// `-?\d+(\.\d+)?` off the front of `text`.
  private static func number(_ text: inout Substring) -> String? {
    var end = text.startIndex
    if end < text.endIndex, text[end] == "-" { end = text.index(after: end) }
    let digitsStart = end
    while end < text.endIndex, text[end].isASCIIDigit { end = text.index(after: end) }
    guard end > digitsStart else { return nil }
    if end < text.endIndex, text[end] == "." {
      var fraction = text.index(after: end)
      let fractionStart = fraction
      while fraction < text.endIndex, text[fraction].isASCIIDigit {
        fraction = text.index(after: fraction)
      }
      if fraction > fractionStart { end = fraction }
    }
    let value = String(text[text.startIndex..<end])
    text = text[end...]
    return value
  }

  private static func isDecimalComma(_ text: String) -> Bool {
    let body = text.hasPrefix("-") ? text.dropFirst() : Substring(text)
    let halves = body.split(separator: ",", omittingEmptySubsequences: false)
    return halves.count == 2 && halves.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }
  }
}

extension CoordinateEntry {
  static func text(_ value: Double?) -> String { PlaceSearch.coordinateText(value) }
}

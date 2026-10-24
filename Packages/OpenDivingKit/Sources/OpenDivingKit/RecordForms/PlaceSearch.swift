import Foundation

/// What a place search row would place, by where it came from: only a catalogue row names the
/// site itself.
public enum PlacePick: Hashable, Sendable {
  case geocode(GeocodeResult)
  case catalog(DiveSiteSuggestion)
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

  /// The dive site search's two sources in one list, catalogue rows first, a geocoded row
  /// dropped where it is the same OpenStreetMap record as a catalogue row.
  public static func siteRows(
    catalog: [DiveSiteSuggestion], geocoded: [GeocodeResult], position: DeviceLocation?,
    units: UnitSystem
  ) -> [PlaceSearchRow] {
    var rows: [PlaceSearchRow] = []
    var seen: Set<String> = []
    for site in catalog {
      let id = "catalog:\(site.source):\(site.sourceId)"
      guard seen.insert(id).inserted else { continue }
      rows.append(
        PlaceSearchRow(
          id: id, name: site.name, hint: catalogHint(site, position: position, units: units),
          pick: .catalog(site)))
    }
    for result in geocoded {
      let sameRecord = catalog.contains { site in
        result.source != nil && result.sourceId != nil && result.source == site.source
          && result.sourceId == site.sourceId
      }
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

  /// What a catalogue row says besides its name: the diver's own site that carries its entry,
  /// its English name where that differs, where it is, and how far from the position the form
  /// has (`catalogHint`).
  public static func catalogHint(
    _ site: DiveSiteSuggestion, position: DeviceLocation?, units: UnitSystem
  ) -> String? {
    var parts: [String] = []
    if let held = site.heldSite { parts.append("In your sites as \(held.name)") }
    if let english = site.nameEn?.trimmedOfWhitespace, !english.isEmpty,
      english != site.name.trimmedOfWhitespace
    {
      parts.append(english)
    }
    if let place = placeContext(region: site.region, country: site.country) {
      parts.append(place)
    }
    if let position {
      let meters = GeoDistance.haversineMeters(
        fromLatitude: position.latitude, longitude: position.longitude,
        toLatitude: site.latitude, longitude: site.longitude)
      parts.append(GeoDistance.format(meters, units))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

  /// The place a catalogue row names: `region, country`, or nil where the record has neither.
  public static func location(of site: DiveSiteSuggestion) -> LocationWrite? {
    placeContext(region: site.region, country: site.country).map { LocationWrite(name: $0) }
  }

  /// A catalogue pick's registry entry added to the site's, replacing the one the previous pick
  /// in the same sheet added (`pickExternalId`). Returns the list and the entry this pick
  /// added, nil where the site already had it.
  public static func pickExternalId(
    _ current: [ExternalIdWrite], replacing earlier: ExternalIdWrite?, with picked: ExternalIdRead
  ) -> (externalIds: [ExternalIdWrite], added: ExternalIdWrite?) {
    let entry = ExternalIdWrite(registry: picked.registry, identifier: picked.identifier)
    let kept = earlier.map { earlier in current.filter { $0 != earlier } } ?? current
    if kept.contains(entry) { return (kept, nil) }
    return (kept + [entry], entry)
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

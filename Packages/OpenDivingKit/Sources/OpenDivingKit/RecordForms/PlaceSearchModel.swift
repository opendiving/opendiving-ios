import Foundation
import Observation

/// The words a place search shows, which differ by what it finds.
public struct PlaceSearchText: Hashable, Sendable {
  public let placeholder: String
  public let noItems: String
  public let noMatches: String
  public let searchError: String
  public let queryTooLong: String

  /// The dive site's *Search location*: the catalogue's sites and the geocoder's places.
  public static let diveSite = PlaceSearchText(
    placeholder: "e.g. Thistlegorm",
    noItems: "Type to search dive sites and places.",
    noMatches:
      "Nothing found - press Enter to use it as typed, or place the site on the map.",
    searchError:
      "Couldn't reach the search - press Enter to use it as typed, or place the site on the map.",
    queryTooLong: "Too long to search for a dive site.")

  /// A trip part's place.
  public static let tripPart = PlaceSearchText(
    placeholder: "Search for a place...",
    noItems: "Type to search places.",
    noMatches: "No places found - press Enter to add as text.",
    searchError: "Couldn't reach the place search - press Enter to add as text.",
    queryTooLong: "Too long to search - press Enter to add as text.")
}

/// One place search box's state: the rows for what was typed, or the line saying why there
/// are none, and every credit the rows shown so far owe — kept for the sheet, since a licence
/// condition of data already shown does not lapse with the next query.
@MainActor
@Observable
public final class PlaceSearchModel {
  public enum State: Hashable, Sendable {
    /// Too short to ask either source.
    case idle
    case tooLong
    case searching
    case results([PlaceSearchRow], hasMore: Bool)
    case noMatches
    case failed
  }

  public typealias Catalog =
    @MainActor (_ query: String, _ near: DeviceLocation?) async throws -> DiveSiteSuggestResponse
  public typealias Geocode = @MainActor (_ query: String) async throws -> [GeocodeResult]

  public private(set) var state: State = .idle
  public private(set) var attributions: [String] = []
  public let text: PlaceSearchText

  @ObservationIgnored private let catalog: Catalog?
  @ObservationIgnored private let geocode: Geocode
  @ObservationIgnored private let debounce: Duration
  @ObservationIgnored private var generation = 0

  /// Without `catalog`, the box finds places alone, as a trip part's does.
  public init(
    text: PlaceSearchText, catalog: Catalog?, geocode: @escaping Geocode,
    debounce: Duration = PlaceSearch.debounce
  ) {
    self.text = text
    self.catalog = catalog
    self.geocode = geocode
    self.debounce = debounce
  }

  /// Over the session's client; the dive site's search asks the catalogue too.
  public convenience init(session: Session, findsSites: Bool) {
    var catalog: Catalog?
    if findsSites {
      catalog = { query, near in
        let client = try session.requireClient()
        return try await client.diveSiteSuggestions(
          query: query, latitude: near?.latitude, longitude: near?.longitude)
      }
    }
    let geocode: Geocode = { query in
      let client = try session.requireClient()
      return try await client.geocodeSearch(query: query)
    }
    self.init(text: findsSites ? .diveSite : .tripPart, catalog: catalog, geocode: geocode)
  }

  /// Searches for `query`, after the debounce; a newer search makes this one's answer moot.
  /// The two sources settle apart, so one of them down is a shorter list rather than an
  /// error, and only both failing is.
  public func search(_ query: String, near position: DeviceLocation?, units: UnitSystem) async {
    generation += 1
    let mine = generation
    let trimmed = query.trimmedOfWhitespace
    guard trimmed.count >= PlaceSearch.minQueryLength else {
      state = .idle
      return
    }
    guard trimmed.count <= PlaceSearch.maxQueryLength else {
      state = .tooLong
      return
    }
    state = .searching
    try? await Task.sleep(for: debounce)
    guard mine == generation, !Task.isCancelled else { return }

    // Both asked at once, as the web's `allSettled` asks them.
    let catalog = catalog
    let geocode = geocode
    async let suggested = Self.settle { try await catalog?(trimmed, position) }
    async let found = Self.settle { try await geocode(trimmed) }
    let (suggestedAnswer, foundAnswer) = await (suggested, found)
    guard mine == generation else { return }
    let suggestions = (try? suggestedAnswer.get()) ?? nil
    let catalogFailed = (try? suggestedAnswer.get()) == nil
    let places = try? foundAnswer.get()

    if places == nil && (catalog == nil || catalogFailed) {
      state = .failed
      return
    }
    let rows =
      catalog == nil
      ? PlaceSearch.placeRows(places ?? [])
      : PlaceSearch.siteRows(
        catalog: suggestions?.results ?? [], geocoded: places ?? [], position: position,
        units: units)
    let credits =
      (suggestions?.results.map(\.attribution) ?? []) + (places ?? []).map(\.attribution)
    for credit in credits where !credit.isEmpty && !attributions.contains(credit) {
      attributions.append(credit)
    }
    state = rows.isEmpty ? .noMatches : .results(rows, hasMore: suggestions?.hasMore ?? false)
  }

  private static func settle<Value: Sendable>(_ work: @MainActor () async throws -> Value) async
    -> Result<Value, any Error>
  {
    do { return .success(try await work()) } catch { return .failure(error) }
  }

  /// The box emptied, or a pick made: no list until the next query.
  public func clear() {
    generation += 1
    state = .idle
  }
}

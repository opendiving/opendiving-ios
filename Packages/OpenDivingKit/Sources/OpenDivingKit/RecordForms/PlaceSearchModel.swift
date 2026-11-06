import Foundation
import Observation

/// The words a place search shows, which differ by what it finds.
public struct PlaceSearchText: Hashable, Sendable {
  public let placeholder: String
  public let queryTooLong: String
  private let noMatches: String
  private let searchError: String
  /// How the two sentences above go on where the picker has a map to place on.
  private let onTheMap: String

  public func noMatches(hasMap: Bool) -> String { sentence(noMatches, hasMap: hasMap) }

  public func searchError(hasMap: Bool) -> String { sentence(searchError, hasMap: hasMap) }

  private func sentence(_ start: String, hasMap: Bool) -> String {
    start + (hasMap ? onTheMap : "") + "."
  }

  /// A dive site's location picker: Commons records and the geocoder's places.
  public static let diveSite = PlaceSearchText(
    placeholder: "Search sites or paste coordinates",
    queryTooLong: "Too long to search for a dive site.",
    noMatches: "Nothing found",
    searchError: "Couldn't reach the search",
    onTheMap: ", place the site on the map instead")

  /// The same search where a form has no use for a Commons record: the places alone.
  public static let diveSitePlace = PlaceSearchText(
    placeholder: "Search or paste coordinates",
    queryTooLong: "Too long to search for a place.",
    noMatches: "Nothing found",
    searchError: "Couldn't reach the search",
    onTheMap: ", place the site on the map instead")

  /// A trip part's place.
  public static let tripPart = PlaceSearchText(
    placeholder: "Search or paste coordinates",
    queryTooLong: "Too long to search for a place.",
    noMatches: "No places found",
    searchError: "Couldn't reach the place search",
    onTheMap: ", tap the map instead")
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

  /// What a box finds.
  public enum Finds: Hashable, Sendable {
    case tripPlaces
    case sitePlaces
    case commonsAndPlaces
  }

  public typealias Commons =
    @MainActor (_ query: String, _ near: DeviceLocation?) async throws
    -> PaginatedListResponse<DiveSiteLookupItem>
  public typealias Geocode = @MainActor (_ query: String) async throws -> [GeocodeResult]

  public private(set) var state: State = .idle
  public private(set) var attributions: [String] = []
  public let text: PlaceSearchText

  @ObservationIgnored private let commons: Commons?
  @ObservationIgnored private let geocode: Geocode
  @ObservationIgnored private let debounce: Duration
  @ObservationIgnored private var generation = 0

  /// Without `commons`, the box finds places alone.
  public init(
    text: PlaceSearchText, commons: Commons?, geocode: @escaping Geocode,
    debounce: Duration = PlaceSearch.debounce
  ) {
    self.text = text
    self.commons = commons
    self.geocode = geocode
    self.debounce = debounce
  }

  /// How many Commons records one search lists.
  static let commonsPageSize = 10

  /// Over the session's client.
  public convenience init(session: Session, finds: Finds) {
    var commons: Commons?
    if finds == .commonsAndPlaces {
      commons = { query, near in
        let client = try session.requireClient()
        return try await client.lookupDiveSites(
          search: query, near: near, commonsOnly: true, page: 1,
          itemsPerPage: Self.commonsPageSize)
      }
    }
    let geocode: Geocode = { query in
      let client = try session.requireClient()
      return try await client.geocodeSearch(query: query)
    }
    let text: PlaceSearchText =
      switch finds {
      case .tripPlaces: .tripPart
      case .sitePlaces: .diveSitePlace
      case .commonsAndPlaces: .diveSite
      }
    self.init(text: text, commons: commons, geocode: geocode)
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
    let commons = commons
    let geocode = geocode
    async let listed = Self.settle { try await commons?(trimmed, position) }
    async let found = Self.settle { try await geocode(trimmed) }
    let (listedAnswer, foundAnswer) = await (listed, found)
    guard mine == generation else { return }
    let records = (try? listedAnswer.get()) ?? nil
    let commonsFailed = (try? listedAnswer.get()) == nil
    let places = try? foundAnswer.get()

    if places == nil && (commons == nil || commonsFailed) {
      state = .failed
      return
    }
    let rows =
      text == .tripPart
      ? PlaceSearch.placeRows(places ?? [])
      : PlaceSearch.siteRows(
        commons: records?.data ?? [], geocoded: places ?? [], query: trimmed, position: position,
        units: units)
    let credits =
      (records?.data.compactMap(\.attribution) ?? []) + (places ?? []).map(\.attribution)
    credits.forEach(owe)
    state = rows.isEmpty ? .noMatches : .results(rows, hasMore: records?.hasMore ?? false)
  }

  private static func settle<Value: Sendable>(_ work: @MainActor () async throws -> Value) async
    -> Result<Value, any Error>
  {
    do { return .success(try await work()) } catch { return .failure(error) }
  }

  /// A credit from outside the search, a looked-up position's, kept with the rest.
  public func owe(_ credit: String) {
    if !credit.isEmpty && !attributions.contains(credit) { attributions.append(credit) }
  }

  /// The box emptied, or a pick made: no list until the next query.
  public func clear() {
    generation += 1
    state = .idle
  }
}

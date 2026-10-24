import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// What the dive form and the record forms read: the pickers' lookups, the suggestions, the
// searches. `until` is the start of the dive being edited, so the records a dive of its time
// used rank first; nil ranks as of now.
extension APIClient {
  // MARK: - Lookups

  /// `GET /dive-sites/lookup`. `uuids` narrows the page to sites a form already holds.
  public func lookupDiveSites(
    search: String? = nil, until: DiveTimestamp? = nil, uuids: [UUID] = [], page: Int,
    itemsPerPage: Int = listPageSize
  ) async throws -> PaginatedListResponse<DiveSiteLookupItem> {
    try await lookup(
      "dive-sites/lookup", search: search, until: until, uuids: uuids, page: page,
      itemsPerPage: itemsPerPage)
  }

  /// `GET /trips/lookup`. `uuids` narrows the page to trips a form already holds.
  public func lookupTrips(
    search: String? = nil, until: DiveTimestamp? = nil, uuids: [UUID] = [], page: Int,
    itemsPerPage: Int = listPageSize
  ) async throws -> PaginatedListResponse<TripLookupItem> {
    try await lookup(
      "trips/lookup", search: search, until: until, uuids: uuids, page: page,
      itemsPerPage: itemsPerPage)
  }

  /// `GET /courses/lookup`. `uuids` narrows the page to courses a form already holds.
  public func lookupCourses(
    search: String? = nil, until: DiveTimestamp? = nil, uuids: [UUID] = [], page: Int,
    itemsPerPage: Int = listPageSize
  ) async throws -> PaginatedListResponse<CourseLookupItem> {
    try await lookup(
      "courses/lookup", search: search, until: until, uuids: uuids, page: page,
      itemsPerPage: itemsPerPage)
  }

  /// `GET /contacts/lookup`.
  public func lookupContacts(
    search: String? = nil, until: DiveTimestamp? = nil, page: Int,
    itemsPerPage: Int = listPageSize
  ) async throws -> PaginatedListResponse<ContactLookupItem> {
    try await lookup(
      "contacts/lookup", search: search, until: until, page: page, itemsPerPage: itemsPerPage)
  }

  /// `GET /people/lookup`.
  public func lookupPeople(
    search: String? = nil, until: DiveTimestamp? = nil, page: Int,
    itemsPerPage: Int = listPageSize
  ) async throws -> PaginatedListResponse<PersonLookupItem> {
    try await lookup(
      "people/lookup", search: search, until: until, page: page, itemsPerPage: itemsPerPage)
  }

  /// `GET /gear-items/lookup`: kit in service, archived items never listed. `type` narrows
  /// it, `cylinder` for a tank's picker.
  public func lookupGearItems(
    search: String? = nil, until: DiveTimestamp? = nil, type: String? = nil, page: Int,
    itemsPerPage: Int = listPageSize
  ) async throws -> PaginatedListResponse<GearItemLookupItem> {
    try await lookup(
      "gear-items/lookup", search: search, until: until, page: page, itemsPerPage: itemsPerPage,
      extra: type.map { [URLQueryItem(name: "type", value: $0)] } ?? [])
  }

  /// `GET /gear-sets`, by name.
  public func gearSets(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<GearSetRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<GearSetRead>.self,
      Call(path: "gear-sets", query: Self.paging(page, itemsPerPage)))
  }

  // MARK: - The dive form

  /// `GET /dives/next-number`: the number to suggest for a dive starting at `startTime`,
  /// which carries its offset.
  public func nextDiveNumber(startTime: DiveTimestamp) async throws -> DiveNumberSuggestion {
    try await authorizedDecoded(
      DiveNumberSuggestion.self,
      Call(
        path: "dives/next-number",
        query: [URLQueryItem(name: "start_time", value: startTime.wireValue)]))
  }

  /// `GET /dives/recent-volumes`: the cylinder volumes dives at or before `until` used.
  public func recentVolumes(until: DiveTimestamp? = nil) async throws -> RecentVolumes {
    try await authorizedDecoded(
      RecentVolumes.self,
      Call(
        path: "dives/recent-volumes",
        query: until.map { [URLQueryItem(name: "until", value: $0.wireValue)] } ?? []))
  }

  /// `GET /user/species/suggest`: the species logged at `diveSiteUUIDs` first, then the rest
  /// of the life list, then the catalog's matches for `query`, leaving out `excluding`.
  public func speciesSuggest(
    query: String, diveSiteUUIDs: [UUID] = [], excluding: [UUID] = []
  ) async throws -> SpeciesSuggestResponse {
    var items = [URLQueryItem(name: "q", value: query)]
    items += diveSiteUUIDs.map { URLQueryItem(name: "dive_site_uuid", value: Self.wire($0)) }
    items += excluding.map { URLQueryItem(name: "exclude_species_uuid", value: Self.wire($0)) }
    return try await authorizedDecoded(
      SpeciesSuggestResponse.self, Call(path: "user/species/suggest", query: items))
  }

  // MARK: - Places

  /// `GET /geocode/search`: places by name, never a street. Empty when nothing matched and
  /// when the instance cannot ask.
  public func geocodeSearch(query: String) async throws -> [GeocodeResult] {
    try await authorizedDecoded(
      [GeocodeResult].self,
      Call(path: "geocode/search", query: [URLQueryItem(name: "q", value: query)]))
  }

  /// `GET /geocode/reverse`: the place at a position.
  public func geocodeReverse(latitude: Double, longitude: Double) async throws
    -> ReverseGeocode
  {
    let (data, response) = try await authorized(
      Call(
        path: "geocode/reverse",
        query: [
          URLQueryItem(name: "lat", value: String(latitude)),
          URLQueryItem(name: "lon", value: String(longitude)),
        ]))
    if response.statusCode == 204 { return .nameless }
    guard let result = try decode(GeocodeResult?.self, data, response) else { return .unknown }
    return .named(result)
  }

  /// `GET /dive-sites/suggest`: named dive sites from the server's catalog, nearest a
  /// position first when the form has one.
  public func diveSiteSuggestions(
    query: String, latitude: Double? = nil, longitude: Double? = nil
  ) async throws -> DiveSiteSuggestResponse {
    var items = [URLQueryItem(name: "q", value: query)]
    if let latitude, let longitude {
      items.append(URLQueryItem(name: "latitude", value: String(latitude)))
      items.append(URLQueryItem(name: "longitude", value: String(longitude)))
    }
    return try await authorizedDecoded(
      DiveSiteSuggestResponse.self, Call(path: "dive-sites/suggest", query: items))
  }

  // MARK: - The account

  /// `GET /user/storage`.
  public func storage() async throws -> StorageUsageRead {
    try await authorizedDecoded(StorageUsageRead.self, Call(path: "user/storage"))
  }

  // MARK: - Sending

  private func lookup<Item: Decodable & Sendable>(
    _ path: String, search: String?, until: DiveTimestamp?, uuids: [UUID] = [], page: Int,
    itemsPerPage: Int, extra: [URLQueryItem] = []
  ) async throws -> PaginatedListResponse<Item> {
    var items = Self.paging(page, itemsPerPage)
    if let search, !search.isEmpty {
      items.append(URLQueryItem(name: "search", value: search))
    }
    if let until {
      items.append(URLQueryItem(name: "until", value: until.wireValue))
    }
    items += uuids.map { URLQueryItem(name: "uuid", value: Self.wire($0)) }
    return try await authorizedDecoded(
      PaginatedListResponse<Item>.self, Call(path: path, query: items + extra))
  }
}

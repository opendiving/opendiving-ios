import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// The site finder's three reads: the search, and the two documents its map draws.
extension APIClient {
  /// How many site rows one page of the finder's list asks for.
  public static let searchPageSize = 25

  /// `GET /dive-sites/search`: sites and places in one order, to render as they come.
  public func searchDiveSites(
    _ query: DiveSiteSearchQuery, page: Int, itemsPerPage: Int = searchPageSize
  ) async throws -> DiveSiteSearchPage {
    try await authorizedDecoded(
      DiveSiteSearchPage.self,
      Call(path: "dive-sites/search", query: query.items + Self.paging(page, itemsPerPage)))
  }

  /// `GET /dive-sites/points`: the pins of every site on the diver's list.
  public func diveSitePoints() async throws -> DiveSitePoints {
    try await authorizedDecoded(DiveSitePoints.self, Call(path: "dive-sites/points"))
  }

  /// `GET /commons/dive-sites/points`, sent with the stored `ETag`: every Commons record with a
  /// pin, as the bytes the server sent, which ``CommonsDiveSitePoints/decode(_:)`` reads.
  public func commonsDiveSitePoints(etag: String?) async throws -> ConditionalFetch<Data> {
    let (data, response) = try await authorized(
      Call(path: "commons/dive-sites/points", etag: etag))
    if response.statusCode == 304 { return .notModified }
    try check(data, response)
    // Read before it is kept, so a body this build cannot read is never what the phone holds.
    do {
      _ = try CommonsDiveSitePoints.decode(data)
    } catch {
      throw APIError.unreadableResponse(String(describing: error))
    }
    return .fetched(data, etag: response.value(forHTTPHeaderField: "ETag"))
  }
}

import Foundation

/// One page of `GET /dive-sites/search`: the rows in the server's order, which a list renders as
/// they come. `hasMore` counts site rows alone.
public struct DiveSiteSearchPage: Decodable, Sendable {
  public let rows: [DiveSiteSearchRow]
  public let hasMore: Bool
  /// With `yours`, how many site rows the filters admit.
  public let totalCount: Int?
  public let page: Int
  public let itemsPerPage: Int

  enum CodingKeys: String, CodingKey {
    case rows, hasMore, totalCount, page, itemsPerPage
  }

  public init(
    rows: [DiveSiteSearchRow], hasMore: Bool, totalCount: Int? = nil, page: Int,
    itemsPerPage: Int
  ) {
    self.rows = rows
    self.hasMore = hasMore
    self.totalCount = totalCount
    self.page = page
    self.itemsPerPage = itemsPerPage
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    var rows: [DiveSiteSearchRow] = []
    var list = try c.nestedUnkeyedContainer(forKey: .rows)
    while !list.isAtEnd {
      // A later kind of row is left out rather than failing the page.
      if let row = try? list.decode(DiveSiteSearchRow.self) {
        rows.append(row)
      } else {
        _ = try list.decode(Skipped.self)
      }
    }
    self.rows = rows
    hasMore = try c.decode(Bool.self, forKey: .hasMore)
    totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount)
    page = try c.decode(Int.self, forKey: .page)
    itemsPerPage = try c.decode(Int.self, forKey: .itemsPerPage)
  }

  /// The page as a list's page, the shape ``PagedList`` reads.
  public var listPage: PaginatedListResponse<DiveSiteSearchRow> {
    PaginatedListResponse(
      data: rows, totalCount: totalCount ?? rows.count, hasMore: hasMore, page: page,
      itemsPerPage: itemsPerPage)
  }

  /// Whatever a row this build cannot read holds, read past.
  private struct Skipped: Decodable {}
}

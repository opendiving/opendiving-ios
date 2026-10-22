/// One page of a list route.
public struct PaginatedListResponse<Item: Codable & Sendable>: Codable, Sendable {
  public let data: [Item]
  public let totalCount: Int
  public let hasMore: Bool
  public let page: Int
  public let itemsPerPage: Int

  public init(data: [Item], totalCount: Int, hasMore: Bool, page: Int, itemsPerPage: Int) {
    self.data = data
    self.totalCount = totalCount
    self.hasMore = hasMore
    self.page = page
    self.itemsPerPage = itemsPerPage
  }
}

extension PaginatedListResponse: Equatable where Item: Equatable {}
extension PaginatedListResponse: Hashable where Item: Hashable {}

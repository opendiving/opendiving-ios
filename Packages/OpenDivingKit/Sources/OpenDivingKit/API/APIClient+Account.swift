import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension APIClient {
  // MARK: - The account

  /// `PATCH /user`, which sends only what `update` sets. Its answer is a message, so the
  /// account is read again to see it.
  public func updateUser(_ update: UserUpdate) async throws {
    try await authorizedChecked(Call(method: "PATCH", path: "user", body: Self.json(update)))
  }

  /// `POST /user/email-change/request`: mails a confirmation link to `newEmail`, superseding
  /// any earlier one. The account's address changes only once the link is confirmed, on the
  /// web's page; the answer is the same whether or not another account holds the address.
  public func requestEmailChange(to newEmail: String) async throws {
    try await authorizedChecked(
      Call(
        method: "POST", path: "user/email-change/request",
        body: Self.json(EmailChangeRequest(newEmail: newEmail))))
  }

  // MARK: - Tags

  /// `GET /tags`, one page, by name, each with how many dives and sites carry it.
  public func tags(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<TagRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<TagRead>.self,
      Call(path: "tags", query: Self.paging(page, itemsPerPage)))
  }

  /// `PATCH /tag/{uuid}`: every dive and site carrying the tag carries the new name. A name
  /// another of the diver's tags has, compared case-folded, is a 422 naming the clash.
  public func renameTag(_ uuid: UUID, to name: String) async throws {
    try await authorizedChecked(
      Call(method: "PATCH", path: "tag/\(Self.wire(uuid))", body: Self.json(TagUpdate(name: name))))
  }

  /// `DELETE /tag/{uuid}`: the dives and sites carrying it keep everything else.
  public func deleteTag(_ uuid: UUID) async throws {
    try await authorizedChecked(Call(method: "DELETE", path: "tag/\(Self.wire(uuid))"))
  }
}

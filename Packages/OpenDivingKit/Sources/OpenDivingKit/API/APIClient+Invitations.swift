import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension APIClient {
  /// `GET /user/invitations`, newest first. An instance anyone may join answers 404.
  public func invitations(page: Int, itemsPerPage: Int) async throws
    -> PaginatedListResponse<InvitationRead>
  {
    try await authorizedDecoded(
      PaginatedListResponse<InvitationRead>.self,
      Call(path: "user/invitations", query: Self.paging(page, itemsPerPage)))
  }

  /// `DELETE /user/invitation/{uuid}`: the row stays, stamped revoked. An accepted one is a 409.
  public func revokeInvitation(_ uuid: UUID) async throws {
    try await authorizedChecked(
      Call(method: "DELETE", path: "user/invitation/\(Self.wire(uuid))"))
  }

  /// `GET /user/invite-link`, or nil when the diver has none. An instance anyone may join
  /// answers the same 404, so this is asked only once the invitations list has answered.
  public func inviteLink() async throws -> InviteLinkRead? {
    do {
      return try await authorizedDecoded(InviteLinkRead.self, Call(path: "user/invite-link"))
    } catch APIError.http(status: 404, _) {
      return nil
    }
  }

  /// `POST /user/invite-link`: makes the link, or replaces its token, so the old address stops
  /// admitting anyone at once.
  public func createInviteLink() async throws -> InviteLinkRead {
    try await authorizedDecoded(
      InviteLinkRead.self, Call(method: "POST", path: "user/invite-link"))
  }

  /// `DELETE /user/invite-link`, which succeeds with nothing to remove too.
  public func removeInviteLink() async throws {
    try await authorizedChecked(Call(method: "DELETE", path: "user/invite-link"))
  }
}

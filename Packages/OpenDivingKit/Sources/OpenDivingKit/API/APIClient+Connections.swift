import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// The ties between the diver's people and accounts: *Added you*, the pictures a tie shows, and
// the writes that make and cut one.
extension APIClient {
  /// `GET /people/added-you`, one page, ordered by name.
  public func addedYou(page: Int, itemsPerPage: Int = listPageSize) async throws
    -> PaginatedListResponse<AddedYouRow>
  {
    try await authorizedDecoded(
      PaginatedListResponse<AddedYouRow>.self,
      Call(path: "people/added-you", query: Self.paging(page, itemsPerPage)))
  }

  /// `POST /people/added-you/{uuid}/hide`: the row leaves the list and nothing else changes.
  public func hideAddedYou(_ account: UUID) async throws {
    try await authorizedChecked(
      Call(method: "POST", path: "people/added-you/\(Self.wire(account))/hide"))
  }

  /// `POST /people/added-you/{uuid}/disconnect`: cuts that account's tie to the diver.
  public func disconnectAddedYou(_ account: UUID) async throws {
    try await authorizedChecked(
      Call(method: "POST", path: "people/added-you/\(Self.wire(account))/disconnect"))
  }

  /// `PATCH /person/{uuid}`, which sends only what `update` sets. Its answer is a message.
  public func updatePerson(_ uuid: UUID, _ update: PersonUpdate) async throws {
    try await authorizedChecked(
      Call(method: "PATCH", path: "person/\(Self.wire(uuid))", body: Self.json(update)))
  }

  /// `GET /person/{uuid}/avatar?v=`, `version` being the person's `avatarSha256`. Sent without
  /// an `ETag`: the version is the picture's digest, so a phone holding it never asks.
  public func personAvatar(_ uuid: UUID, version: String) async throws -> FetchedBytes {
    try await picture(Call(path: "person/\(Self.wire(uuid))/avatar", query: Self.version(version)))
  }

  /// `GET /people/added-you/{uuid}/avatar?v=`, `version` being the row's `avatarSha256`.
  public func addedYouAvatar(_ account: UUID, version: String) async throws -> FetchedBytes {
    try await picture(
      Call(path: "people/added-you/\(Self.wire(account))/avatar", query: Self.version(version)))
  }

  /// A picture's `?v=`, which the server ignores and which gives each version an address of its
  /// own.
  private static func version(_ version: String) -> [URLQueryItem] {
    [URLQueryItem(name: "v", value: version)]
  }

  private func picture(_ call: Call) async throws -> FetchedBytes {
    let (data, response) = try await authorized(call)
    try check(data, response)
    return FetchedBytes(data: data, response: response)
  }
}

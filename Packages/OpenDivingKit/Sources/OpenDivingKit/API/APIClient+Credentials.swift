import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension APIClient {
  // MARK: - Passkeys

  /// `GET /user/passkeys`, oldest first, unpaginated. A server without passkeys answers 404.
  public func passkeys() async throws -> [PasskeyRead] {
    try await authorizedDecoded([PasskeyRead].self, Call(path: "user/passkeys"))
  }

  /// `PATCH /user/passkey/{uuid}`. Its answer is a message.
  public func renamePasskey(_ uuid: UUID, to name: String) async throws {
    try await authorizedChecked(
      Call(
        method: "PATCH", path: "user/passkey/\(Self.wire(uuid))",
        body: Self.json(PasskeyUpdate(name: name))))
  }

  /// `DELETE /user/passkey/{uuid}`: the passkey can no longer sign in, for good.
  public func deletePasskey(_ uuid: UUID) async throws {
    try await authorizedChecked(Call(method: "DELETE", path: "user/passkey/\(Self.wire(uuid))"))
  }

  // MARK: - Signed-in devices

  /// `GET /user/sessions`, most recently used first, unpaginated. A server without
  /// server-side sessions answers 404.
  public func userSessions() async throws -> [UserSessionRead] {
    try await authorizedDecoded([UserSessionRead].self, Call(path: "user/sessions"))
  }

  /// `DELETE /user/session/{uuid}`: that device is refused from its next request. The
  /// phone's own session is a 409; signing out is what ends that.
  public func revokeUserSession(_ uuid: UUID) async throws {
    try await authorizedChecked(Call(method: "DELETE", path: "user/session/\(Self.wire(uuid))"))
  }

  /// `DELETE /user/sessions`: every session but this phone's.
  public func revokeOtherUserSessions() async throws -> SessionsRevoked {
    try await authorizedDecoded(
      SessionsRevoked.self, Call(method: "DELETE", path: "user/sessions"))
  }

  // MARK: - API keys

  /// `GET /user/api-keys`, oldest first, expired ones included, unpaginated. A server without
  /// API keys answers 404.
  public func apiKeys() async throws -> [APIKeyRead] {
    try await authorizedDecoded([APIKeyRead].self, Call(path: "user/api-keys"))
  }

  /// `POST /user/api-keys`, whose answer is the only one carrying the key's secret. A 409 at
  /// the account's cap and a 429 past the rate limit each carry the API's sentence.
  public func createAPIKey(_ body: APIKeyCreate) async throws -> APIKeyCreated {
    try await authorizedDecoded(
      APIKeyCreated.self, Call(method: "POST", path: "user/api-keys", body: Self.json(body)))
  }

  /// `DELETE /user/api-key/{uuid}`: the key is refused from its next request.
  public func revokeAPIKey(_ uuid: UUID) async throws {
    try await authorizedChecked(Call(method: "DELETE", path: "user/api-key/\(Self.wire(uuid))"))
  }
}

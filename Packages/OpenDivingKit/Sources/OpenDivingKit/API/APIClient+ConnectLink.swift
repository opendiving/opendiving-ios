import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension APIClient {
  /// `GET /user/connect-link`, or nil when the diver has none.
  public func connectLink() async throws -> ConnectLinkRead? {
    do {
      return try await authorizedDecoded(ConnectLinkRead.self, Call(path: "user/connect-link"))
    } catch APIError.http(status: 404, _) {
      return nil
    }
  }

  /// `POST /user/connect-link`: makes the link, or replaces its token, so the old address stops
  /// resolving at once.
  public func createConnectLink() async throws -> ConnectLinkRead {
    try await authorizedDecoded(
      ConnectLinkRead.self, Call(method: "POST", path: "user/connect-link"))
  }

  /// `DELETE /user/connect-link`, which succeeds with nothing to remove too.
  public func removeConnectLink() async throws {
    try await authorizedChecked(Call(method: "DELETE", path: "user/connect-link"))
  }
}

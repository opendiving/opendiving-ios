import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension APIClient {
  /// `PATCH /user/checkin-details`: replaces the members `update` carries, and answers the
  /// details whole as they then stand.
  public func updateCheckinDetails(_ update: CheckinDetailsUpdate) async throws
    -> CheckinDetailsRead
  {
    try await authorizedDecoded(
      CheckinDetailsRead.self,
      Call(method: "PATCH", path: "user/checkin-details", body: Self.json(update)))
  }
}

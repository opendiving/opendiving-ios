import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// The account's dive computers in its order, which decides the recording a dive shows by default.
extension APIClient {
  /// `GET /dive-computers`: the account's computers, first to last; empty for none. A 404 from a
  /// server that keeps no order.
  public func diveComputers() async throws -> [DiveComputerRead] {
    try await authorizedDecoded([DiveComputerRead].self, Call(path: "dive-computers"))
  }

  /// `PUT /dive-computers/order`: the whole order, first to last, answering what
  /// ``diveComputers()`` then answers. A serial no recording names yet is kept; a repeated one is
  /// a 422.
  public func setDiveComputerOrder(_ serials: [String]) async throws -> [DiveComputerRead] {
    try await authorizedDecoded(
      [DiveComputerRead].self,
      Call(
        method: "PUT", path: "dive-computers/order",
        body: Self.json(DiveComputerOrder(serials: serials))))
  }
}

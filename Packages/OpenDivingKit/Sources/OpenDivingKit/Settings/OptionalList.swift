import Observation

/// A settings list a server may not have: a read whose 404 means the feature is absent there —
/// an API older than it, or one where it does not apply — and the block showing it is left
/// out, rather than reporting an error. Any other failure keeps what was already read and says
/// why. The read is direct and needs a route: with none it fails at once with the
/// no-connection sentence, and ``followRoute()`` reads again once one appears.
@MainActor
@Observable
public final class OptionalList<Value: Sendable> {
  /// Nil until a read lands, and again once the server has said it has no such list.
  public private(set) var value: Value?
  /// The server answered the read with 404: the block is left out.
  public private(set) var isAbsent = false
  /// Why the last read failed, until one lands.
  public private(set) var failure: String?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let read: @Sendable (APIClient) async throws -> Value

  public init(session: Session, read: @escaping @Sendable (APIClient) async throws -> Value) {
    self.session = session
    self.read = read
  }

  public func load() async {
    do {
      let client = try session.routedClient()
      let read = read
      value = try await read(client)
      isAbsent = false
      failure = nil
    } catch is CancellationError {
    } catch {
      let error = APIError(error)
      if case .http(status: 404, _) = error {
        value = nil
        isAbsent = true
        failure = nil
      } else {
        failure = error.message
      }
    }
  }

  /// Reads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }

  /// Changes what was read in place — a rename, a row added from a write's answer — without
  /// reading again. Nothing happens before a read has landed.
  public func update(_ change: (Value) -> Value) {
    guard let value else { return }
    self.value = change(value)
  }
}

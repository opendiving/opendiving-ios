import Observation

/// *Data*'s storage: what the account's uploads take up, read each time the screen shows and
/// each time a route appears. A direct read, online only.
@MainActor
@Observable
public final class StorageModel {
  /// Nil until the first read lands.
  public private(set) var usage: StorageUsageRead?
  /// Why the last read failed, shown while there is no usage to show.
  public private(set) var loadFailure: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
  }

  /// `GET /user/storage`. With no route nothing is asked for: a usage already read stays.
  public func load() async {
    do {
      usage = try await session.routedClient().storage()
      loadFailure = nil
    } catch is CancellationError {
    } catch {
      loadFailure = APIError(error).message
    }
  }

  /// Reads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }
}

import Synchronization

/// An ``ActiveOriginStore`` that forgets with the process.
public final class InMemoryActiveOriginStore: ActiveOriginStore {
  private let origin: Mutex<ServerOrigin?>

  public init(_ origin: ServerOrigin? = nil) {
    self.origin = Mutex(origin)
  }

  public func load() -> ServerOrigin? {
    origin.withLock { $0 }
  }

  public func save(_ origin: ServerOrigin?) {
    self.origin.withLock { $0 = origin }
  }
}

/// Where a detail page's record stands: on its way, on screen, gone from the server, or
/// failed to arrive.
public enum DetailPhase<Record: Hashable & Sendable>: Hashable, Sendable {
  case loading
  case loaded(Record)
  /// The server answered 404: deleted since the link to it was drawn, or never the
  /// diver's.
  case notFound
  case failed(APIError)

  public var isLoaded: Bool {
    if case .loaded = self { true } else { false }
  }

  /// A failed read: a 404 is ``notFound``, anything else ``failed(_:)``.
  public static func failure(_ error: any Error) -> DetailPhase {
    let error = APIError(error)
    if case .http(status: 404, _) = error { return .notFound }
    return .failed(error)
  }
}

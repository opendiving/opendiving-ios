/// What a list or a detail shows in place of its content: still loading, nothing there,
/// the record gone, or a failure to retry.
public enum ContentStatus: Hashable, Sendable {
  case loading
  /// `title` names the absence — "No dives logged yet", not "Nothing here".
  case empty(systemImage: String, title: String, message: String?)
  case notFound(message: String)
  /// Offers *Try again*.
  case failed(message: String)
}

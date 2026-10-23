import Foundation

/// A picture or a document as a bytes route served it.
public struct FetchedBytes: Hashable, Sendable {
  public let data: Data
  /// The `Content-Type` the server sniffed: `image/webp`, `image/jpeg`, `image/png` or
  /// `application/pdf`.
  public let contentType: String?

  public init(data: Data, contentType: String?) {
    self.data = data
    self.contentType = contentType
  }
}

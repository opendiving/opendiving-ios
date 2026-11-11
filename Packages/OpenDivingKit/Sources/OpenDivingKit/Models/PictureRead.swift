/// What a write to either picture answers: its rendition's digest, the `?v=` of its download.
public struct PictureRead: Codable, Hashable, Sendable {
  public let sha256: String
}

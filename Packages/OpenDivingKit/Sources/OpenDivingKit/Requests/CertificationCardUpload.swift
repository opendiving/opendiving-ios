/// One face of a certification's card, as the file routes name it.
public enum CertificationSide: String, Codable, Hashable, Sendable, CaseIterable {
  case front, back
}

/// A card image waiting to be sent with `PUT /certification/{uuid}/file/{side}`: what the
/// multipart part says about the bytes the outbox keeps beside the item. The API tells the kind
/// from the bytes; the name is what a download is saved as.
public struct CertificationCardUpload: Codable, Hashable, Sendable {
  public var side: CertificationSide
  public var filename: String
  /// `image/jpeg`, `image/png`, `image/webp` or `application/pdf`.
  public var contentType: String

  public init(side: CertificationSide, filename: String, contentType: String) {
    self.side = side
    self.filename = filename
    self.contentType = contentType
  }
}

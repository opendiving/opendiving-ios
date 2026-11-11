/// The body of `PATCH /user/{avatar,portrait}` and `POST /user/portrait/from-avatar`: a new crop
/// over an original the server holds.
public struct PictureCropRequest: Codable, Hashable, Sendable {
  public var crop: PictureCrop

  public init(crop: PictureCrop) {
    self.crop = crop
  }
}

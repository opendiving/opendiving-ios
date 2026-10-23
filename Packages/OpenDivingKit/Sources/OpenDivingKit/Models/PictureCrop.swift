/// Where a picture was cropped from its original, in the upright original's pixels.
public struct PictureCrop: Codable, Hashable, Sendable {
  public let x: Int
  public let y: Int
  public let width: Int
  public let height: Int
}

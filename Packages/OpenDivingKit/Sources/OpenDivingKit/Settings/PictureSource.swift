import Foundation

/// The image a crop is chosen on: a pick made ready to send, or an original the server holds.
/// The size is the upright one the crop is measured in.
public struct PictureSource: Hashable, Sendable {
  public let data: Data
  public let width: Int
  public let height: Int

  public init(data: Data, width: Int, height: Int) {
    self.data = data
    self.width = width
    self.height = height
  }
}

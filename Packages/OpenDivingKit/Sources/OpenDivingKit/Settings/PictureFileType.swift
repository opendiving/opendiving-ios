import Foundation

/// The two formats the API keeps as a picture's original.
public enum PictureFileType: String, Hashable, Sendable {
  case jpeg = "image/jpeg"
  case png = "image/png"

  private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

  /// The type the bytes say they are, as the API reads it; nil for any other format.
  public init?(sniffing data: Data) {
    let head = [UInt8](data.prefix(8))
    if head.starts(with: [0xFF, 0xD8, 0xFF]) {
      self = .jpeg
    } else if head == Self.pngSignature {
      self = .png
    } else {
      return nil
    }
  }

  public var fileExtension: String {
    switch self {
    case .jpeg: "jpg"
    case .png: "png"
    }
  }
}

import Foundation

/// A crop being chosen: on what, from where, and what it becomes once chosen.
public struct PictureCropping: Hashable, Sendable, Identifiable {
  public enum Purpose: Hashable, Sendable {
    case replace(filename: String, type: PictureFileType)
    case adjust
    case copy
  }

  public let id = UUID()
  public let purpose: Purpose
  public let source: PictureSource
  /// Where the frame opens; nil centres it.
  public let initial: PictureCrop?

  public init(purpose: Purpose, source: PictureSource, initial: PictureCrop? = nil) {
    self.purpose = purpose
    self.source = source
    self.initial = initial
  }

  /// The edit `area`, chosen on this, makes.
  public func edit(cropping area: CropFrame.Area, kind: PictureKind) -> PictureEdit {
    let crop = PictureCrop.fitted(
      area, imageWidth: source.width, imageHeight: source.height, kind: kind)
    switch purpose {
    case .replace(let filename, let type):
      return .replace(source, filename: filename, type: type, crop: crop)
    case .adjust: return .adjust(source, crop: crop)
    case .copy: return .copy(source, crop: crop)
    }
  }
}

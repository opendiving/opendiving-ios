/// Why a picture could not be picked or opened, as the screen says it.
public struct PictureRefusal: Error, Hashable, Sendable {
  public let title: String
  public let message: String

  public init(title: String, message: String) {
    self.title = title
    self.message = message
  }

  public static let unreadable = PictureRefusal(title: "Error", message: PictureLimits.unreadable)
  public static let tooLarge = PictureRefusal(
    title: PictureLimits.tooLargeTitle, message: PictureLimits.tooLargeBytes)

  public static func tooLarge(_ problem: String) -> PictureRefusal {
    PictureRefusal(title: PictureLimits.tooLargeTitle, message: problem)
  }

  static func couldNotLoad(_ kind: PictureKind, _ reason: String) -> PictureRefusal {
    PictureRefusal(title: "Your \(kind.label) could not be loaded", message: reason)
  }
}

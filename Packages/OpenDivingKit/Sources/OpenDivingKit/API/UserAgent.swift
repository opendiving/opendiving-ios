/// `OpenDiving-iOS/<version> (iOS <version>; <model>)`. The model is the bare word
/// `UIDevice.model` gives, `iPhone`: the web's sessions page names a device by matching
/// `\biPhone\b`, which an identifier like `iPhone17,1` fails.
public struct UserAgent: Hashable, Sendable {
  public let appVersion: String
  public let systemVersion: String
  public let model: String

  public init(appVersion: String, systemVersion: String, model: String) {
    self.appVersion = appVersion
    self.systemVersion = systemVersion
    self.model = model
  }

  public var headerValue: String {
    "OpenDiving-iOS/\(appVersion) (iOS \(systemVersion); \(model))"
  }
}

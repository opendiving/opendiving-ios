import Foundation
import OpenDivingKit

/// The active server, under the app's own defaults: it is no secret, and it outlives every
/// sign-out until the server is forgotten.
nonisolated struct DefaultsActiveOriginStore: ActiveOriginStore {
  static let key = "activeServerOrigin"

  func load() -> ServerOrigin? {
    UserDefaults.standard.string(forKey: Self.key).flatMap(ServerOrigin.init)
  }

  func save(_ origin: ServerOrigin?) {
    if let origin {
      UserDefaults.standard.set(origin.description, forKey: Self.key)
    } else {
      UserDefaults.standard.removeObject(forKey: Self.key)
    }
  }
}

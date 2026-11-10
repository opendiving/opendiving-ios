import Foundation
import Observation

/// The appearance the whole app is drawn in, from the sign-in screens to every sheet and map.
/// Kept in the defaults beside nothing a server owns, so a sign-out, a change of server, a
/// *Forget* and a relaunch all leave it; a fresh install is ``Appearance/system``.
@MainActor
@Observable
public final class AppearanceModel {
  public var choice: Appearance {
    didSet { defaults.set(choice.rawValue, forKey: Self.key) }
  }

  @ObservationIgnored private let defaults: UserDefaults
  static let key = "appearance"

  public init(defaults: UserDefaults) {
    self.defaults = defaults
    choice = defaults.string(forKey: Self.key).flatMap(Appearance.init(rawValue:)) ?? .system
  }
}

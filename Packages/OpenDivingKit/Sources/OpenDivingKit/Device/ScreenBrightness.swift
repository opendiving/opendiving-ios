/// The screen's backlight, as the full-screen card view raises it and puts it back. A
/// protocol because the Kit builds where UIKit does not exist: the app target conforms it
/// over its window scene's screen, and a view model's tests over a fake.
@MainActor
public protocol ScreenBrightness: AnyObject {
  /// The current level, from 0 to 1.
  func currentLevel() -> Double
  /// Sets the level, clamped to 0...1 by the conformance.
  func setLevel(_ level: Double)
}

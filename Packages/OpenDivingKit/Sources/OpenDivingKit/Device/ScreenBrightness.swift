/// The screen's backlight, as the full-screen card view raises it and puts it back. The app
/// target conforms it over its window scene's screen; the Kit's tests conform it with a
/// fake, which is why it is a protocol rather than a call into UIKit.
@MainActor
public protocol ScreenBrightness: AnyObject {
  /// The current level, from 0 to 1.
  func currentLevel() -> Double
  /// Sets the level, clamped to 0...1 by the conformance.
  func setLevel(_ level: Double)
}

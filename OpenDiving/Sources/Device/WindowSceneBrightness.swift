import OpenDivingKit
import UIKit

/// The screen of the foreground window scene, the one `UIScreen.main` used to name.
final class WindowSceneBrightness: ScreenBrightness {
  func currentLevel() -> Double {
    screen.map { Double($0.brightness) } ?? 1
  }

  func setLevel(_ level: Double) {
    screen?.brightness = CGFloat(min(max(level, 0), 1))
  }

  /// The active scene's, or — as the app resigns active and the brightness is put back — the
  /// scene that was active a moment ago and is now inactive.
  private var screen: UIScreen? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene =
      scenes.first { $0.activationState == .foregroundActive }
      ?? scenes.first { $0.activationState == .foregroundInactive }
    return scene?.screen
  }
}

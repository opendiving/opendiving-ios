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

  private var screen: UIScreen? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }?
      .screen
  }
}

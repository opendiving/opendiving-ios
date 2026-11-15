import SwiftUI

extension View {
  /// A secondary action's bordered button, its tint given rather than left to the default, which
  /// Increase Contrast brightens.
  func brandBorderedButton(_ color: Color = .accentText) -> some View {
    buttonStyle(.bordered).tint(color)
  }
}

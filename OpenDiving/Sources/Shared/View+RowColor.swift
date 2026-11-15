import SwiftUI

extension View {
  /// A row's action in the accent, set as a colour: with Increase Contrast on, iOS brightens the
  /// default tint, and a colour is drawn as it stands.
  func accentRow() -> some View {
    modifier(RowColor(color: .accentText))
  }

  /// A row's destructive action in the web's danger colour.
  func dangerRow() -> some View {
    modifier(RowColor(color: .danger))
  }
}

/// A colour set by hand replaces the system's dimming, so a disabled row asks for it back.
private struct RowColor: ViewModifier {
  let color: Color

  @Environment(\.isEnabled) private var isEnabled

  func body(content: Content) -> some View {
    content.foregroundStyle(isEnabled ? color : Color.secondary)
  }
}

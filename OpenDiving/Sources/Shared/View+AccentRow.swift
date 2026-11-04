import SwiftUI

extension View {
  /// A row's action in the accent. A tint will not do: iOS 26 lightens tinted text in a list in the
  /// dark and darkens it in the light, so it is set as a colour, which is drawn as it stands.
  func accentRow() -> some View {
    modifier(AccentRow())
  }
}

private struct AccentRow: ViewModifier {
  @Environment(\.isEnabled) private var isEnabled

  func body(content: Content) -> some View {
    content.foregroundStyle(isEnabled ? Color.accentText : Color.secondary)
  }
}

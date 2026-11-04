import SwiftUI

/// A place in coral ringed in the page's colour, and a fix the same two colours inverted, as the
/// web draws them: one legend, two claims.
struct MapMarker: View {
  static let diameter: CGFloat = 12
  /// #FF7F50, the brand's coral, which the web's pins are drawn in for reading on both themes.
  private static let coral = Color(red: 1, green: 127 / 255, blue: 80 / 255)

  var isFix = false

  var body: some View {
    Circle()
      .fill(isFix ? Color(.systemBackground).opacity(0.8) : Self.coral)
      .strokeBorder(isFix ? Self.coral : Color(.systemBackground), lineWidth: 2)
      .frame(width: Self.diameter, height: Self.diameter)
      .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
  }
}

#Preview {
  HStack {
    MapMarker()
    MapMarker(isFix: true)
  }
}

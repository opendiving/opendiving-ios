import SwiftUI

/// A place in coral ringed in the page's colour, and a fix the same two colours inverted, as the
/// web draws them: one legend, two claims.
struct MapMarker: View {
  static let diameter: CGFloat = 12
  var isFix = false

  var body: some View {
    Circle()
      .fill(isFix ? Color(.systemBackground).opacity(0.8) : Color.brandCoral)
      .strokeBorder(isFix ? Color.brandCoral : Color(.systemBackground), lineWidth: 2)
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

import SwiftUI

// What floats on a full-screen map: the location picker's and the site finder's.
extension View {
  /// A control floating on the map: the toolbar's glass, or its material before iOS 26.
  @ViewBuilder func pickerControl(in shape: some Shape) -> some View {
    if #available(iOS 26, *) {
      glassEffect(.regular.interactive(), in: shape)
    } else {
      background(.regularMaterial, in: shape)
    }
  }

  /// A card over the map: a material rather than glass, which iOS 26 draws close to opaque over
  /// dark tiles, with the corners of a form's section, which each system draws its own and neither
  /// names: measured, 26 and 10.
  func pickerCard() -> some View {
    let radius: Double
    if #available(iOS 26, *) { radius = 26 } else { radius = 10 }
    return background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius))
  }
}

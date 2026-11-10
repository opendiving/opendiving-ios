import SwiftUI

// What floats on a full-screen map: the location picker's and the site finder's.
extension View {
  /// A control floating on the map: the toolbar's glass, or its material before iOS 26; tinted,
  /// a control switched on.
  @ViewBuilder func pickerControl(in shape: some Shape, tint: Color? = nil) -> some View {
    if #available(iOS 26, *) {
      glassEffect(.regular.tint(tint).interactive(), in: shape)
    } else if let tint {
      background(tint, in: shape)
    } else {
      background(.regularMaterial, in: shape)
    }
  }

  /// A card over the map: a material rather than glass, which iOS 26 draws close to opaque over
  /// dark tiles, with the corners of a form's section.
  func pickerCard() -> some View {
    background(.thinMaterial, in: .formSection)
  }
}

import OpenDivingKit
import SwiftUI
import UIKit

/// A card with no map to show — nowhere on a map yet, an instance with no map, or a tile that
/// could not be had: the map's open water, in the colour the web names its sea, with the
/// record's icon centred in what the details leave of it, muted so it sits in the water.
struct UnplacedBackdropView: View {
  let icon: OpenDivingKit.Icon
  var coveredTop: CGFloat = 0
  let coveredBottom: CGFloat

  private static let waterForeground = Color(
    UIColor {
      $0.userInterfaceStyle == .dark
        ? UIColor(red: 178 / 255, green: 226 / 255, blue: 226 / 255, alpha: 1)
        : UIColor(red: 37 / 255, green: 96 / 255, blue: 96 / 255, alpha: 1)
    })

  var body: some View {
    Color.mapWater
      .overlay {
        Image(icon)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: 40, height: 40)
          .foregroundStyle(Self.waterForeground)
          .saturation(0.5)
          .opacity(0.6)
          .padding(.top, coveredTop)
          .padding(.bottom, coveredBottom)
      }
      .accessibilityHidden(true)
  }
}

#Preview {
  UnplacedBackdropView(icon: .tabLuggage, coveredBottom: 100)
    .frame(height: 240)
}

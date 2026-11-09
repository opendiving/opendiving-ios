import OpenDivingKit
import SwiftUI

/// A round control floating on a full-screen map before iOS 26, its symbol white on teal while it
/// is on. From iOS 26 `mapRoundButton(isOn:)` draws the system's glass button instead.
struct MapRoundButtonStyle: ButtonStyle {
  static let side = 44.0

  var isOn = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(width: Self.side, height: Self.side)
      .contentShape(Circle())
      .foregroundStyle(isOn ? Color.white : Color.primary)
      .pickerControl(in: Circle(), tint: isOn ? Color.brandTeal : nil)
      .opacity(configuration.isPressed ? 0.6 : 1)
  }
}

extension View {
  /// A round button floating on the map, the size and glass of a top bar's button; teal while on.
  @ViewBuilder func mapRoundButton(isOn: Bool = false) -> some View {
    if #available(iOS 26, *) {
      let sized = frame(
        width: MapRoundButtonStyle.glassLabelSide, height: MapRoundButtonStyle.glassLabelSide
      )
      .buttonBorderShape(.circle)
      if isOn {
        sized.buttonStyle(.glassProminent).tint(Color.brandTeal)
      } else {
        sized.buttonStyle(.glass).foregroundStyle(Color.primary)
      }
    } else {
      buttonStyle(MapRoundButtonStyle(isOn: isOn))
    }
  }

  /// A button in the top bar over the map. From iOS 26 the bar draws its own glass around it, so
  /// it keeps the system's look; before, the bar over the map draws nothing, and it floats round.
  @ViewBuilder func mapBarButton(isOn: Bool = false) -> some View {
    if #available(iOS 26, *) {
      if isOn {
        buttonStyle(.borderedProminent).tint(Color.brandTeal)
      } else {
        self
      }
    } else {
      buttonStyle(MapRoundButtonStyle(isOn: isOn)).labelStyle(.iconOnly)
    }
  }
}

extension MapRoundButtonStyle {
  /// The label inside the system's glass button, which pads it by 7 a side to a top bar button's 44:
  /// measured, as the system names neither.
  static let glassLabelSide = 30.0
}

#Preview {
  HStack(spacing: 12) {
    Button {
    } label: {
      Image(Icon.locateFixed)
    }
    .mapRoundButton()
    Button {
    } label: {
      Image(Icon.bookmark)
    }
    .mapRoundButton(isOn: true)
  }
  .padding()
  .background(Color.blue.opacity(0.3))
}

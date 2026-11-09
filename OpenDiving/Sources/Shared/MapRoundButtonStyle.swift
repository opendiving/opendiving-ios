import OpenDivingKit
import SwiftUI

/// A round control floating on a full-screen map, its symbol white on teal while it is on.
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

#Preview {
  HStack(spacing: 12) {
    Button {
    } label: {
      Image(Icon.locateFixed)
    }
    .buttonStyle(MapRoundButtonStyle())
    Button {
    } label: {
      Image(Icon.bookmark)
    }
    .buttonStyle(MapRoundButtonStyle(isOn: true))
  }
  .padding()
  .background(Color.blue.opacity(0.3))
}

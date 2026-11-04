import OpenDivingKit
import SwiftUI

/// Keeps a form's ``MapStyleModel`` on the style for the screen's colour scheme, asking when the
/// form appears.
private struct MapStyleLoader: ViewModifier {
  let model: MapStyleModel

  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content.task(id: colorScheme) {
      await model.show(colorScheme == .dark ? .dark : .light)
    }
  }
}

extension View {
  func showsMapStyle(_ model: MapStyleModel) -> some View {
    modifier(MapStyleLoader(model: model))
  }
}

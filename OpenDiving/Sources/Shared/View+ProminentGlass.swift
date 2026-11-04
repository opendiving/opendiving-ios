import SwiftUI

extension View {
  /// The filled button of a screen's main action, on Liquid Glass where the system has it.
  @ViewBuilder func prominentGlassButton() -> some View {
    if #available(iOS 26, *) {
      buttonStyle(.glassProminent)
    } else {
      buttonStyle(.borderedProminent)
    }
  }
}

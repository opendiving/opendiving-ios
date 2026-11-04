import SwiftUI

extension View {
  /// The filled teal button of a screen's main action, on Liquid Glass where the system has it.
  @ViewBuilder func brandProminentButton() -> some View {
    if #available(iOS 26, *) {
      buttonStyle(.glassProminent).tint(.brandTeal)
    } else {
      buttonStyle(.borderedProminent).tint(.brandTeal)
    }
  }
}

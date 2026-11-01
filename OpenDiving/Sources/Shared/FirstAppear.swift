import SwiftUI

/// Runs once, when the view first appears — not again when a screen pushed over it pops back.
struct FirstAppear: ViewModifier {
  let action: () -> Void
  @State private var appeared = false

  func body(content: Content) -> some View {
    content.onAppear {
      guard !appeared else { return }
      appeared = true
      action()
    }
  }
}

extension View {
  func onFirstAppear(perform action: @escaping () -> Void) -> some View {
    modifier(FirstAppear(action: action))
  }
}

#Preview {
  Text("Appeared once").onFirstAppear {}
}

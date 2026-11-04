import SwiftUI

extension View {
  /// A field's label, which focuses the box when tapped.
  func focusesOnTap(_ focus: FocusState<Bool>.Binding) -> some View {
    contentShape(Rectangle())
      .onTapGesture { focus.wrappedValue = true }
  }
}

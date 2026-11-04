import SwiftUI

extension View {
  /// A form row's swipe-left Delete, in the web's danger fill. `onDelete` draws the system's red
  /// and takes no tint.
  func swipeToDelete(_ action: @escaping () -> Void) -> some View {
    swipeActions {
      Button("Delete", role: .destructive, action: action)
        .tint(.dangerFill)
    }
  }
}

import SwiftUI

extension View {
  /// A picker's list starts just under its search field, not a grouped list's section gap below.
  func pickerListSpacing() -> some View {
    contentMargins(.top, 8, for: .scrollContent)
  }
}

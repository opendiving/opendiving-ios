import SwiftUI

extension View {
  /// A round button's label on the site finder's panel, as its close buttons are: a circle a
  /// finger's width, on the search field's fill.
  func panelRoundButton() -> some View {
    frame(width: 44, height: 44)
      .background(Color(.secondarySystemGroupedBackground), in: Circle())
      .contentShape(Circle())
  }
}

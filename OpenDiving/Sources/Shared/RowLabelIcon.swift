import OpenDivingKit
import SwiftUI

/// A list row's symbol, loaded as the row needs it, in the accent set as a colour the way the
/// row's own actions are, so iOS 26 does not shift it as it does the tint.
struct RowLabelIcon: View {
  let icon: Icon

  var body: some View {
    Image(loaded: icon).accentRow()
  }
}

#Preview {
  List {
    Label(row: "Account", icon: .user)
  }
}

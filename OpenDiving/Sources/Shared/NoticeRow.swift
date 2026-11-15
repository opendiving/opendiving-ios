import SwiftUI

/// A sentence about what the screen just did, its symbol in the accent: on the servers and
/// add-server screens, and the code screen's resend.
struct NoticeRow: View {
  let notice: String
  var systemImage = "info.circle"

  var body: some View {
    Label {
      Text(notice)
    } icon: {
      Image(systemName: systemImage).accentRow()
    }
  }
}

#Preview {
  Form {
    NoticeRow(
      notice:
        "You stopped waiting for the server to sign out, so the session there may stay open until it expires."
    )
    NoticeRow(notice: "A new code is on its way.", systemImage: "checkmark.circle")
  }
}

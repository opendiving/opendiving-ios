import OpenDivingKit
import SwiftUI

/// The mark beside a record the phone has created and the server has not yet been sent.
struct PendingMark: View {
  let ref: RecordRef?

  var body: some View {
    if ref?.isLocal == true {
      Label("Not sent yet", systemImage: "clock")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  PendingMark(ref: .local(UUID()))
}

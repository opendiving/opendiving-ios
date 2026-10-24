import OpenDivingKit
import SwiftUI

/// The drafts a new form offers before it is touched — the server's and the phone's alike —
/// each by its start or *Untitled draft* and when it last changed.
struct DiveDraftChooser: View {
  let rows: [DiveDraftRowContent]
  let onPick: (RecordRef) -> Void

  var body: some View {
    Section("Continue a draft") {
      ForEach(rows) { row in
        Button {
          onPick(row.ref)
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(row.title).foregroundStyle(.primary)
              if row.isPending { PendingMark() }
            }
            Text(row.detail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

#Preview {
  Form {
    DiveDraftChooser(rows: []) { _ in }
  }
}

import OpenDivingKit
import SwiftUI

/// What *Log a dive* offers while drafts exist: a new dive, or one of the drafts — the server's
/// and the phone's alike — each by its start or *Untitled draft* and when it last changed.
struct DiveDraftChooser: View {
  let rows: [DiveDraftRowContent]
  let onNew: () -> Void
  let onPick: (RecordRef) -> Void

  var body: some View {
    List {
      Section {
        Button("New dive", systemImage: "plus", action: onNew)
      }
      Section("Drafts") {
        ForEach(rows) { row in
          Button {
            onPick(row.ref)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                Text(row.title).foregroundStyle(.primary)
                if row.isPending {
                  Image(systemName: "icloud.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Not yet on the server")
                }
              }
              Text(row.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .navigationTitle("Log New Dive")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    DiveDraftChooser(rows: [], onNew: {}, onPick: { _ in })
  }
}

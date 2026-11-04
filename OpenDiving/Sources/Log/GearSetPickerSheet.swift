import OpenDivingKit
import SwiftUI

/// The diver's gear sets, searched as they type. A new set comes from *Save as set*, so this has
/// no + of its own.
struct GearSetPickerSheet: View {
  let sets: [GearSetRow]
  let onPick: (GearSetRow) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var text = ""

  var body: some View {
    NavigationStack {
      let rows = LookupsModel.matching(sets, text)
      List {
        ForEach(rows, id: \.ref) { set in
          Button {
            onPick(set)
            dismiss()
          } label: {
            Text(DiveFormModel.setLabel(set)).foregroundStyle(Color.primary)
          }
        }
        if rows.isEmpty {
          Text("No gear sets found.").foregroundStyle(.secondary)
        }
      }
      .searchable(
        text: $text, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Load a gear set..."
      )
      .navigationTitle("Load a gear set...")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}

#Preview {
  GearSetPickerSheet(sets: []) { _ in }
}

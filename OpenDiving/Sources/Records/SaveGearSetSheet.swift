import OpenDivingKit
import SwiftUI

/// The sheet that saves the gear checked on a dive as a set, with its weight, or reopens a
/// queued save the server refused (`failedItem`); `onSaved` hands back the set's ref. Saving
/// sets on the phone arrives in a later version, which this sheet says until then.
struct SaveGearSetSheet: View {
  let items: [RecordRef]
  let weight: Double?
  let failedItem: UUID?
  let onSaved: (RecordRef) -> Void

  init(
    items: [RecordRef], weight: Double?, failedItem: UUID? = nil,
    onSaved: @escaping (RecordRef) -> Void
  ) {
    self.items = items
    self.weight = weight
    self.failedItem = failedItem
    self.onSaved = onSaved
  }

  var body: some View {
    RecordSheetPlaceholder(title: "Save as a gear set", systemImage: "list.bullet.rectangle")
  }
}

#Preview {
  SaveGearSetSheet(items: [], weight: nil) { _ in }
}

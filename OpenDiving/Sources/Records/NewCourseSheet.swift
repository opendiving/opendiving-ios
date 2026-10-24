import OpenDivingKit
import SwiftUI

/// The sheet that creates a record from a picker, or reopens a queued create the server
/// refused (`failedItem`); `onCreated` hands back the new record's ref. Creating records on the
/// phone arrives in a later version, which this sheet says until then.
struct NewCourseSheet: View {
  let failedItem: UUID?
  let onCreated: (RecordRef) -> Void

  init(failedItem: UUID? = nil, onCreated: @escaping (RecordRef) -> Void) {
    self.failedItem = failedItem
    self.onCreated = onCreated
  }

  var body: some View {
    RecordSheetPlaceholder(title: "New course", systemImage: "graduationcap")
  }
}

#Preview {
  NewCourseSheet { _ in }
}

import SwiftUI

/// The last section of an edit form: its record's delete, which says what goes before it does.
struct DeleteRecordSection: View {
  let title: String
  let message: String
  let action: () -> Void

  @State private var confirms = false

  var body: some View {
    Section {
      Button(title, role: .destructive) { confirms = true }
        .dangerRow()
        .confirmationDialog(title, isPresented: $confirms, titleVisibility: .visible) {
          Button("Delete", role: .destructive, action: action)
        } message: {
          Text(message)
        }
    }
  }
}

#Preview {
  Form {
    DeleteRecordSection(title: "Delete trip", message: "The dives stay.") {}
  }
}

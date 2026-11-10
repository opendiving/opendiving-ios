import SwiftUI

/// The last section of an edit form: its record's delete, which says what goes before it does.
/// Bare and centred, in the type of the save button under it, so it reads as the form's other
/// action and not as a field.
struct DeleteRecordSection: View {
  let title: String
  let message: String
  /// What the confirming button says, where the form's action is not a delete.
  var confirmation = "Delete"
  let action: () -> Void

  @State private var confirms = false

  var body: some View {
    Section {
      Button(role: .destructive) {
        confirms = true
      } label: {
        Text(title)
          .bold()
          .frame(maxWidth: .infinity)
      }
      .dangerRow()
      .listRowBackground(Color.clear)
      .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
      .confirmationDialog(title, isPresented: $confirms, titleVisibility: .visible) {
        Button(confirmation, role: .destructive, action: action)
      } message: {
        Text(message)
      }
    }
    .listSectionSpacing(.compact)
  }
}

#Preview {
  Form {
    DeleteRecordSection(title: "Delete trip", message: "The dives stay.") {}
  }
}

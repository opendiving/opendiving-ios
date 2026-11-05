import OpenDivingKit
import SwiftUI

/// A site's other names, a box each; a blank one is dropped on save.
struct OtherNamesField: View {
  @Binding var names: [String]

  @FocusState private var focused: Int?

  var body: some View {
    Section {
      ForEach(names.indices, id: \.self) { index in
        TextField("Other name \(index + 1)", text: name(index), prompt: Text("e.g. Sunabe Seawall"))
          .focused($focused, equals: index)
          .swipeToDelete { if names.indices.contains(index) { names.remove(at: index) } }
      }
      Button(names.isEmpty ? "Add a name" : "Add another name", systemImage: "plus") {
        names.append("")
        // The box does not exist until the list draws it.
        Task { focused = names.count - 1 }
      }
      .accentRow()
    } header: {
      FormSectionHeader(title: "Other Names", icon: .diveSite)
    }
  }

  /// Read safely: a removed row may draw once more after the list has shrunk under it.
  private func name(_ index: Int) -> Binding<String> {
    Binding(
      get: { names.indices.contains(index) ? names[index] : "" },
      set: { if names.indices.contains(index) { names[index] = $0 } })
  }
}

#Preview {
  @Previewable @State var names = ["El Bells"]
  Form { OtherNamesField(names: $names) }
}

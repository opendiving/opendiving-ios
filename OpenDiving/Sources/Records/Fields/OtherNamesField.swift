import SwiftUI

/// A site's other names, a box each; a blank one is dropped on save.
struct OtherNamesField: View {
  @Binding var names: [String]

  var body: some View {
    Section("Other names") {
      ForEach(names.indices, id: \.self) { index in
        TextField("Other name \(index + 1)", text: name(index), prompt: Text("e.g. Sunabe Seawall"))
      }
      .onDelete { names.remove(atOffsets: $0) }
      Button(names.isEmpty ? "Add a name" : "Add another name", systemImage: "plus") {
        names.append("")
      }
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

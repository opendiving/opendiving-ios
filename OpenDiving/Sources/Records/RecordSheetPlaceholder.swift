import SwiftUI

/// What a record sheet shows until creating records on the phone arrives.
struct RecordSheetPlaceholder: View {
  let title: String
  let systemImage: String

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label(title, systemImage: systemImage)
      } description: {
        Text("Creating records on the phone arrives in a later version. Until then, use the web.")
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}

#Preview {
  RecordSheetPlaceholder(title: "New dive site", systemImage: "mappin.and.ellipse")
}

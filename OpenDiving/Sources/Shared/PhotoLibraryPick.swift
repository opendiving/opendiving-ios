import PhotosUI
import SwiftUI

extension View {
  /// The photo library, while `isPresented`, handing back the picked photo's bytes as the
  /// library holds them — a camera's HEIC stays HEIC — or nil when they could not be read.
  func photoLibraryPick(
    isPresented: Binding<Bool>, onPicked: @escaping @MainActor (Data?) -> Void
  ) -> some View {
    modifier(PhotoLibraryPick(isPresented: isPresented, onPicked: onPicked))
  }
}

private struct PhotoLibraryPick: ViewModifier {
  @Binding var isPresented: Bool
  let onPicked: @MainActor (Data?) -> Void

  @State private var item: PhotosPickerItem?

  func body(content: Content) -> some View {
    content
      .photosPicker(isPresented: $isPresented, selection: $item, matching: .images)
      .onChange(of: item) { _, picked in
        guard let picked else { return }
        // Cleared at once, so picking the same photo again still counts as a change.
        item = nil
        Task { onPicked(try? await picked.loadTransferable(type: Data.self)) }
      }
  }
}

#Preview {
  @Previewable @State var choosing = false
  Button("Photo Library") { choosing = true }
    .photoLibraryPick(isPresented: $choosing) { _ in }
}

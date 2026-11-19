import OpenDivingKit
import SwiftUI

extension View {
  /// The system's file picker for an import: each picked file is read under its security scope,
  /// released before the next, into a staging copy, and the selection lands in the inbox as one
  /// arrival. `onPicked` runs once the inbox has kept it.
  func importFilePicker(isPresented: Binding<Bool>, onPicked: @escaping () -> Void = {})
    -> some View
  {
    modifier(ImportFilePicker(isPresented: isPresented, onPicked: onPicked))
  }
}

private struct ImportFilePicker: ViewModifier {
  @Binding var isPresented: Bool
  let onPicked: () -> Void
  @Environment(InboxModel.self) private var inbox
  @State private var failure: String?

  func body(content: Content) -> some View {
    content
      .fileImporter(
        isPresented: $isPresented, allowedContentTypes: [.item], allowsMultipleSelection: true
      ) { result in
        switch result {
        case .success(let urls): pick(urls)
        case .failure(let error): failure = error.localizedDescription
        }
      }
      .alert(
        "The files could not be picked",
        isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(failure ?? "")
      }
  }

  private func pick(_ urls: [URL]) {
    let staged = urls.compactMap(SharedFileStaging.stage)
    guard !staged.isEmpty else { return }
    if case .notKept(let reason) = inbox.receive(staged, moving: true) {
      failure = reason
    } else {
      onPicked()
    }
  }
}

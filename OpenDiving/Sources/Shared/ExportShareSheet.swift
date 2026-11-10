import OpenDivingKit
import SwiftUI
import UIKit

extension View {
  /// Offers `model`'s finished export to the share sheet, and removes the file once the sheet
  /// closes. Leaving this view cuts off the export on its way and removes the file waiting.
  func sharesExports(_ model: DataExportModel) -> some View {
    sheet(
      item: Binding(
        get: { model.shared },
        set: { if $0 == nil { model.finishSharing() } }),
      onDismiss: { model.finishSharing() }
    ) { file in
      ExportActivityView(file: file.url) { model.finishSharing() }
        .presentationDetents([.medium, .large])
        .ignoresSafeArea()
    }
    .onDisappear { model.stop() }
  }
}

/// The system's share sheet over one file. `finished` runs once the diver has shared it or
/// cancelled, which is after any copy the chosen activity makes.
private struct ExportActivityView: UIViewControllerRepresentable {
  let file: URL
  let finished: () -> Void

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(activityItems: [file], applicationActivities: nil)
    controller.completionWithItemsHandler = { _, _, _, _ in finished() }
    return controller
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

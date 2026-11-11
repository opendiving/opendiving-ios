import SwiftUI
import UIKit

/// The system's camera, handing back the photograph taken; nil when the diver cancels.
struct CameraPicker: UIViewControllerRepresentable {
  let onTaken: (UIImage?) -> Void

  /// Whether the phone has a camera to offer; a simulator has none.
  static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onTaken: onTaken) }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
  {
    let onTaken: (UIImage?) -> Void

    init(onTaken: @escaping (UIImage?) -> Void) {
      self.onTaken = onTaken
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      onTaken(info[.originalImage] as? UIImage)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      onTaken(nil)
    }
  }
}

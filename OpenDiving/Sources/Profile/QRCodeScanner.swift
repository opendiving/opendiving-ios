import AVFoundation
import OpenDivingKit
import SwiftUI
import VisionKit

/// The camera reading QR codes and nothing else, handing over the first code it reads.
struct QRCodeScanner: UIViewControllerRepresentable {
  let found: (String) -> Void

  /// Nil when the scanner can run, after asking for the camera where nobody has yet.
  static func unavailable() async -> ConnectLinkModel.ScannerUnavailable? {
    guard DataScannerViewController.isSupported else { return .unsupported }
    if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
      _ = await AVCaptureDevice.requestAccess(for: .video)
    }
    return DataScannerViewController.isAvailable ? nil : .cameraRefused
  }

  func makeUIViewController(context: Context) -> ScannerHolder {
    let scanner = DataScannerViewController(
      recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
      recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
      isHighlightingEnabled: true)
    scanner.delegate = context.coordinator
    return ScannerHolder(scanner: scanner)
  }

  func updateUIViewController(_ holder: ScannerHolder, context: Context) {
    context.coordinator.found = found
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(found: found)
  }

  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    var found: (String) -> Void
    private var handedOver = false

    init(found: @escaping (String) -> Void) {
      self.found = found
    }

    func dataScanner(
      _ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
      allItems: [RecognizedItem]
    ) {
      guard !handedOver else { return }
      for item in addedItems {
        if case .barcode(let code) = item, let payload = code.payloadStringValue {
          handedOver = true
          dataScanner.stopScanning()
          found(payload)
          return
        }
      }
    }
  }

  /// Starts the scanner once it is on screen, which it needs to be, and stops it as it leaves.
  final class ScannerHolder: UIViewController {
    let scanner: DataScannerViewController

    init(scanner: DataScannerViewController) {
      self.scanner = scanner
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
      super.viewDidLoad()
      addChild(scanner)
      scanner.view.frame = view.bounds
      scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(scanner.view)
      scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      try? scanner.startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      scanner.stopScanning()
    }
  }
}

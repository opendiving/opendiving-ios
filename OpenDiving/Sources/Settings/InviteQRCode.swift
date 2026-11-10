import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// A QR code of an address, drawn module for module. Hidden whenever the app is not active, as
/// ``CopyField`` hides its value, so the app switcher's snapshot never holds the link.
struct InviteQRCode: View {
  let address: String
  let label: String

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    Group {
      if scenePhase == .active, let image = Self.image(address) {
        Image(decorative: image, scale: 1)
          .interpolation(.none)
          .resizable()
          .scaledToFit()
          .accessibilityLabel(label)
          .accessibilityAddTraits(.isImage)
      } else {
        Color(.secondarySystemFill)
          .accessibilityHidden(true)
      }
    }
    .padding(12)
    .background(.white, in: .rect(cornerRadius: 12))
    .frame(maxWidth: 256)
    .aspectRatio(1, contentMode: .fit)
  }

  /// One pixel per module, dark on white, with the symbol's own quiet zone.
  nonisolated static func image(_ text: String) -> CGImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    return CIContext().createCGImage(output, from: output.extent)
  }
}

#Preview {
  InviteQRCode(
    address: "https://opendiving.app/join?via=q7Zr2LmWexampleInviteTokenNotReal0123456",
    label: "QR code of your invite link")
}

import CoreImage
import OpenDivingKit
import Testing

@testable import OpenDiving

/// The invite link's QR code reads back as the address the screen shows.
struct InviteQRCodeTests {
  @Test func theCodeDecodesToTheAddressShown() throws {
    let origins = ["https://opendiving.app", "http://192.168.1.20:3000"]
    for origin in origins {
      let address = InvitationsModel.address(
        token: "q7Zr2LmW-exampleInviteTokenNot_Real0123456", on: try #require(ServerOrigin(origin))
      ).absoluteString
      let image = try #require(InviteQRCode.image(address))
      // Scaled up as the screen draws it: the detector reads nothing at a pixel a module.
      let scaled = CIImage(cgImage: image)
        .samplingNearest()
        .transformed(by: CGAffineTransform(scaleX: 8, y: 8))
      let detector = try #require(
        CIDetector(
          ofType: CIDetectorTypeQRCode, context: nil,
          options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
      let decoded = detector.features(in: scaled).compactMap {
        ($0 as? CIQRCodeFeature)?.messageString
      }
      #expect(decoded == [address])
    }
  }
}

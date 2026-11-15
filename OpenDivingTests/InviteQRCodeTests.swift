import CoreImage
import OpenDivingKit
import SwiftUI
import Testing

@testable import OpenDiving

/// The invite link's QR code, as the screen draws it in either appearance, reads back as the
/// address the screen shows.
@MainActor
struct InviteQRCodeTests {
  /// A flagship invite: the token is 32 hex characters, which puts the symbol at version 6.
  static let flagshipToken = "dd61596d15ae703e0aa5a28b92586efd"

  @Test func aFlagshipInviteIsVersionSixWithTheMark() throws {
    let layout = try #require(InviteQRCode.layout(Self.address(on: "https://opendiving.app")))
    #expect(layout.size == 41)
    #expect(layout.mark != nil)
  }

  @Test func theStandInHiddenFromTheSwitcherIsTheSizeOfTheCode() throws {
    let address = try Self.address(on: "https://opendiving.app")
    let code = try #require(InviteQRCode.layout(address))
    let standIn = try #require(
      InviteQRCode.layout(InviteQRCode.standIn(for: address)))
    #expect(standIn.size == code.size)
  }

  @Test(arguments: [ColorScheme.light, .dark])
  func theCodeDecodesToTheAddressShown(_ scheme: ColorScheme) throws {
    for origin in ["https://opendiving.app", "http://192.168.1.20:3000"] {
      let address = try Self.address(on: origin)
      let layout = try #require(InviteQRCode.layout(address))
      #expect(try Self.decode(Self.render(layout, scheme)) == [address])
    }
  }

  static func address(on origin: String) throws -> String {
    InvitationsModel.address(token: flagshipToken, on: try #require(ServerOrigin(origin)))
      .absoluteString
  }

  /// The symbol at about the size the screen draws it, on the surface it sits on there.
  static func render(_ layout: InviteQRLayout, _ scheme: ColorScheme) throws -> CGImage {
    let renderer = ImageRenderer(
      content: InviteQRSymbol(layout: layout)
        .frame(width: 256, height: 256)
        .background(Color(.systemGroupedBackground))
        .environment(\.colorScheme, scheme))
    renderer.scale = 3
    return try #require(renderer.cgImage)
  }

  static func decode(_ image: CGImage) throws -> [String] {
    let detector = try #require(
      CIDetector(
        ofType: CIDetectorTypeQRCode, context: nil,
        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
    return detector.features(in: CIImage(cgImage: image)).compactMap {
      ($0 as? CIQRCodeFeature)?.messageString
    }
  }
}

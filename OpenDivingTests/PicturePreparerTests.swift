import ImageIO
import OpenDivingKit
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import OpenDiving

/// A picked photo made ready to send: what goes as it is, what is redrawn upright, and that the
/// crop's space — the upright picture — is the space of the bytes sent. The pictures are stored
/// 40 by 30, red on their left half and blue on their right, and tagged to be shown turned a
/// quarter clockwise, as a phone held upright records its camera's sideways sensor: upright they
/// are 30 by 40, red on top.
struct PicturePreparerTests {
  private static let storedSize = (width: 40, height: 30)

  private static func sideways() throws -> CGImage {
    let context = try #require(
      CGContext(
        data: nil, width: storedSize.width, height: storedSize.height, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: storedSize.width / 2, height: storedSize.height))
    context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
    context.fill(
      CGRect(x: storedSize.width / 2, y: 0, width: storedSize.width / 2, height: storedSize.height))
    return try #require(context.makeImage())
  }

  /// The sideways picture encoded as `type`, its orientation tag saying *turn right*.
  private static func encoded(_ type: UTType) throws -> Data {
    let data = NSMutableData()
    let destination = try #require(
      CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(
      destination, try sideways(),
      [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue] as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
  }

  /// A format the API keeps no original of: HEIC, as the camera writes it, where this simulator
  /// can encode one, else TIFF.
  private static var otherFormat: UTType {
    let encodable = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
    return encodable.contains(UTType.heic.identifier) ? .heic : .tiff
  }

  /// The colour at `x`, `y` of the bytes as they are stored, before any orientation applies.
  private static func stored(_ data: Data, x: Int, y: Int) throws -> (red: UInt8, blue: UInt8) {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = try #require(
      CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    // The context's origin is its bottom-left, so the image is moved for row `y` from the top.
    context.draw(
      image,
      in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    return (pixel[0], pixel[2])
  }

  private static func properties(_ data: Data) throws -> [CFString: Any] {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }

  private static func isUprightRedOnTop(_ prepared: PicturePreparer.Prepared) throws {
    #expect(prepared.type == .jpeg)
    #expect(PictureFileType(sniffing: prepared.source.data) == .jpeg)
    #expect(prepared.source.width == 30 && prepared.source.height == 40)
    let properties = try properties(prepared.source.data)
    #expect(properties[kCGImagePropertyPixelWidth] as? Int == 30)
    #expect(properties[kCGImagePropertyPixelHeight] as? Int == 40)
    #expect((properties[kCGImagePropertyOrientation] as? UInt32 ?? 1) == 1)
    let top = try stored(prepared.source.data, x: 15, y: 5)
    let bottom = try stored(prepared.source.data, x: 15, y: 34)
    #expect(top.red > 200 && top.blue < 60)
    #expect(bottom.blue > 200 && bottom.red < 60)
  }

  @Test func aHEICIsRedrawnUprightAsAJPEGAtItsOwnPixels() throws {
    let prepared = try PicturePreparer.prepare(Self.encoded(Self.otherFormat), kind: .avatar).get()
    try Self.isUprightRedOnTop(prepared)
    #expect(prepared.filename == "avatar.jpg")
  }

  @Test func aCamerasPhotographIsEncodedUpright() throws {
    let photograph = UIImage(cgImage: try Self.sideways(), scale: 1, orientation: .right)
    let prepared = try PicturePreparer.prepare(photograph, kind: .portrait).get()
    try Self.isUprightRedOnTop(prepared)
    #expect(prepared.filename == "portrait.jpg")
  }

  @Test func aJPEGGoesAsPickedMeasuredUpright() throws {
    let data = try Self.encoded(.jpeg)
    let prepared = try PicturePreparer.prepare(data, kind: .avatar).get()
    #expect(prepared.source.data == data)
    #expect(prepared.type == .jpeg)
    // The crop is chosen on the upright picture, which is the space the server crops in once
    // it has applied the tag.
    #expect(prepared.source.width == 30 && prepared.source.height == 40)
    #expect(prepared.cropping.purpose == .replace(filename: "avatar.jpg", type: .jpeg))
  }

  @Test func whatIsNoPictureIsRefused() {
    #expect(throws: PictureRefusal.unreadable) {
      try PicturePreparer.prepare(Data("not a picture".utf8), kind: .avatar).get()
    }
  }

  @MainActor
  @Test func bothFieldsHost() {
    let session = Session.stub(transport: StubTransport(routes: [:]))
    for kind in PictureKind.allCases {
      let host = UIHostingController(
        rootView: Form { PictureFieldView(model: PictureFieldModel(kind: kind, session: session)) }
      )
      host.loadViewIfNeeded()
      host.view.layoutIfNeeded()
      #expect(host.viewIfLoaded != nil)
    }
  }
}

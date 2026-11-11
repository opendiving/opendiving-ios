import Foundation
import OpenDivingKit
import Testing

/// The crop the API is sent, the limits a pick meets, and what the phone does to one that does
/// not, against the cases the web's own tests give `toPictureCrop` and `pictureSizeProblem`.
struct PictureCropTests {
  private func withinRatio(_ crop: PictureCrop, _ kind: PictureKind) -> Bool {
    let (width, height) = kind.ratio
    return abs(crop.width * height - crop.height * width) <= max(width, height)
  }

  private func area(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CropFrame.Area {
    CropFrame.Area(x: x, y: y, width: width, height: height)
  }

  // MARK: - The crop

  @Test func theCroppersOwnRectangleGoesThroughUntouched() {
    let crop = PictureCrop.fitted(
      area(0, 72, 3024, 3888), imageWidth: 3024, imageHeight: 4032, kind: .portrait)
    #expect(crop == PictureCrop(x: 0, y: 72, width: 3024, height: 3888))
  }

  @Test func aRectangleAPixelOverTheEdgeComesBackInside() {
    let crop = PictureCrop.fitted(
      area(1, 0, 700, 900), imageWidth: 700, imageHeight: 900, kind: .portrait)
    #expect(crop.x + crop.width <= 700)
    #expect(crop.y + crop.height <= 900)
    #expect(withinRatio(crop, .portrait))
  }

  @Test(arguments: PictureKind.allCases)
  func aFractionalOffRatioRectangleLandsOnWholePixelsAtTheRatio(_ kind: PictureKind) {
    let crop = PictureCrop.fitted(
      area(10.4, 20.6, 333.3, 401.9), imageWidth: 1000, imageHeight: 1000, kind: kind)
    #expect(withinRatio(crop, kind))
    #expect(crop.x >= 0 && crop.y >= 0)
    #expect(crop.x + crop.width <= 1000 && crop.y + crop.height <= 1000)
  }

  @Test func aHeightTheWidthCannotFollowShrinks() {
    // A 7:9 crop 900 high needs 700 wide, and this image has 650.
    let crop = PictureCrop.fitted(
      area(0, 0, 700, 900), imageWidth: 650, imageHeight: 900, kind: .portrait)
    #expect(crop.width <= 650)
    #expect(crop.height < 900)
    #expect(withinRatio(crop, .portrait))
  }

  // MARK: - The frame a crop is chosen in

  @Test func aStoredCropOpensWhereItWas() {
    let stored = PictureCrop(x: 0, y: 47, width: 1080, height: 1389)
    let frame = CropFrame(
      aspect: PictureKind.portrait.aspect, imageWidth: 1080, imageHeight: 1440,
      showing: stored.area)
    let crop = PictureCrop.fitted(
      frame.area, imageWidth: 1080, imageHeight: 1440, kind: .portrait)
    #expect(crop == stored)
  }

  @Test func aCropNarrowerThanTheZoomReachesStillOpensWhereItWas() {
    let stored = PictureCrop(x: 2000, y: 1000, width: 400, height: 400)
    let frame = CropFrame(
      aspect: 1, imageWidth: 4032, imageHeight: 3024, showing: stored.area)
    #expect(frame.maxZoom > CropFrame.defaultMaxZoom)
    #expect(
      PictureCrop.fitted(frame.area, imageWidth: 4032, imageHeight: 3024, kind: .avatar) == stored)
  }

  // MARK: - The limits

  @Test(arguments: [PictureFileType.jpeg, .png])
  func aTwelveMegapixelPhonePhotoPassesEitherWayRound(_ type: PictureFileType) {
    #expect(PictureLimits.sizeProblem(type, width: 4032, height: 3024) == nil)
    #expect(PictureLimits.sizeProblem(type, width: 3024, height: 4032) == nil)
  }

  @Test func aPNGIsHeldToTheDecodeCapAndToldWhatItIs() {
    #expect(PictureLimits.sizeProblem(.png, width: 1179, height: 2556) == nil)
    let problem = PictureLimits.sizeProblem(.png, width: 5712, height: 4284)
    #expect(problem?.contains("4032 × 3024") == true)
    #expect(problem?.contains("5712 × 4284") == true)
  }

  @Test func aJPEGPassesUpToFiftyMegapixelsAndAPanoramaPasses() {
    #expect(PictureLimits.sizeProblem(.jpeg, width: 5712, height: 4284) == nil)
    #expect(PictureLimits.sizeProblem(.jpeg, width: 8000, height: 6000) == nil)
    #expect(PictureLimits.sizeProblem(.jpeg, width: 40000, height: 500) == nil)
    #expect(
      PictureLimits.sizeProblem(.jpeg, width: 10000, height: 5001)?.contains("50 megapixels")
        == true)
  }

  @Test func theTypeIsReadOffTheBytes() {
    #expect(PictureFileType(sniffing: Data([0xFF, 0xD8, 0xFF, 0xE0])) == .jpeg)
    #expect(
      PictureFileType(sniffing: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) == .png)
    // HEIC's `ftyp` box, a WebP's RIFF header, a GIF and nothing at all.
    #expect(PictureFileType(sniffing: Data([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70])) == nil)
    #expect(PictureFileType(sniffing: Data([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0])) == nil)
    #expect(PictureFileType(sniffing: Data("GIF89a".utf8)) == nil)
    #expect(PictureFileType(sniffing: Data()) == nil)
  }

  // MARK: - What the phone does to a pick

  @Test func aJPEGOrPNGInsideTheLimitsGoesAsPicked() {
    #expect(
      PictureLimits.preparation(for: .jpeg, byteCount: 3_000_000, width: 4032, height: 3024)
        == .asPicked(.jpeg))
    #expect(
      PictureLimits.preparation(for: .png, byteCount: 2_000_000, width: 1179, height: 2556)
        == .asPicked(.png))
  }

  @Test func anyOtherFormatIsConvertedAsTheCamerasHEICIs() {
    // A 24 MP HEIC, the default of a recent iPhone's camera, either way round.
    #expect(
      PictureLimits.preparation(for: nil, byteCount: 3_000_000, width: 5712, height: 4284)
        == .convert)
    #expect(
      PictureLimits.preparation(for: nil, byteCount: 3_000_000, width: 4284, height: 5712)
        == .convert)
  }

  @Test func whatTheAPIWouldRefuseAsPickedIsConvertedWhereAJPEGOfItFits() {
    #expect(
      PictureLimits.preparation(for: .png, byteCount: 9_000_000, width: 5712, height: 4284)
        == .convert)
    #expect(
      PictureLimits.preparation(
        for: .jpeg, byteCount: PictureLimits.maxUploadSize + 1, width: 8000, height: 6000)
        == .convert)
  }

  @Test func whatNotEvenAJPEGMayBeIsRefusedInASentence() {
    let refused = PictureLimits.preparation(
      for: nil, byteCount: 9_000_000, width: 10000, height: 5001)
    #expect(
      refused == .refuse("A JPEG can be at most 50 megapixels, and this one is 10000 × 5001."))
    #expect(!PictureLimits.fits(PictureLimits.maxUploadSize + 1))
    #expect(PictureLimits.fits(PictureLimits.maxUploadSize))
  }
}

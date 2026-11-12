import Testing

@testable import OpenDivingKit

struct PhotoPlacementTests {
  private let band = 132.0
  private let width = 361.0

  @Test func aLandscapePhotoIsCardWideAndCentredUnderTheBandsMiddle() throws {
    let placed = try #require(
      PhotoPlacement.card(photoWidth: 1500, photoHeight: 1000, width: width, band: band))
    #expect(placed.width == width)
    #expect(abs(placed.height - 240.666) < 0.001)
    #expect(placed.x == 0)
    #expect(placed.y + placed.height / 2 == band / 2 + 8)
    #expect(placed.y <= 0)
    #expect(placed.y + placed.height - PhotoPlacement.fade >= band)
  }

  @Test func aPortraitPhotoIsCardWideAndCroppedTopAndBottom() throws {
    let placed = try #require(
      PhotoPlacement.card(photoWidth: 800, photoHeight: 1200, width: width, band: band))
    #expect(placed.width == width)
    #expect(placed.x == 0)
    #expect(placed.y + placed.height / 2 == 74)
    #expect(placed.y == 74 - 541.5 / 2)
  }

  @Test func aPanoramaIsScaledUpUntilItsFadeStartsUnderTheGlass() throws {
    let placed = try #require(
      PhotoPlacement.card(photoWidth: 3000, photoHeight: 1000, width: width, band: band))
    #expect(placed.width > width)
    #expect(placed.x == (width - placed.width) / 2)
    #expect(placed.y + placed.height / 2 == 74)
    #expect(abs(placed.y + placed.height - PhotoPlacement.fade - band) < 1e-9)
  }

  @Test func theCardsTopIsNeverUncoveredWhateverTheBand() throws {
    // A band so short that the bottom's reach no longer outweighs the top's.
    let placed = try #require(
      PhotoPlacement(
        photoWidth: 3000, photoHeight: 1000, frameWidth: width, centreY: 200, reachTop: 0,
        reachBottom: 210))
    #expect(placed.y == 0)
    #expect(placed.y + placed.height / 2 == 200)
  }

  @Test func aHeroIsCutAtItsTopWhateverThePhotosShape() throws {
    for (photoWidth, photoHeight) in [(1500.0, 1000.0), (500.0, 667.0), (3000.0, 1000.0)] {
      let placed = try #require(
        PhotoPlacement.hero(
          photoWidth: photoWidth, photoHeight: photoHeight, width: 393, top: 400,
          uncoveredTop: 516, uncoveredBottom: 750))
      #expect(placed.cutTop == 400)
      #expect(placed.y <= 400)
      #expect(placed.y + placed.height / 2 == 641)
      #expect(placed.y + placed.height - PhotoPlacement.fade >= 750)
      #expect(placed.width >= 393)
    }
  }

  @Test func aHeroShowsAWidePhotosWholeWidthWhereItCan() throws {
    let placed = try #require(
      PhotoPlacement.hero(
        photoWidth: 1500, photoHeight: 1000, width: 393, top: 0, uncoveredTop: 60,
        uncoveredBottom: 140))
    #expect(placed.width == 393)
    #expect(placed.x == 0)
  }

  @Test func aCardShowsItsPhotosOwnTop() throws {
    let placed = try #require(
      PhotoPlacement.card(photoWidth: 1500, photoHeight: 1000, width: width, band: band))
    #expect(placed.cutTop == nil)
  }

  @Test func anEmptyPhotoOrFrameIsNotPlaced() {
    #expect(PhotoPlacement.card(photoWidth: 0, photoHeight: 10, width: width, band: band) == nil)
    #expect(PhotoPlacement.card(photoWidth: 10, photoHeight: 0, width: width, band: band) == nil)
    #expect(PhotoPlacement.card(photoWidth: 10, photoHeight: 10, width: 0, band: band) == nil)
  }
}

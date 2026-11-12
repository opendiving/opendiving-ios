/// Where a backdrop photo is drawn, sharp, in a frame whose foot something covers: as wide as the
/// frame or wider, its centre on a chosen line, and tall enough that its edges reach past the
/// lines they must. What it leaves of the frame is a blurred copy of itself, which its edges fade
/// into over ``fade`` points. Points, from the frame's top-left corner; the photo is never moved
/// off its own centre, which is the only subject the app knows of.
public struct PhotoPlacement: Hashable, Sendable {
  /// How far a sharp photo's edge fades into the blurred copy around it.
  public static let fade = 48.0
  /// How far below the middle of what is left uncovered a photo's centre sits: an animal shot
  /// from above its middle reads as resting on the details rather than hanging over them.
  public static let belowMiddle = 8.0

  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double

  /// The photo centred `centreY` from the frame's top, scaled to the frame's width or up from it
  /// until its top is at or above `reachTop` and its bottom at or below `reachBottom`. Nil for an
  /// empty photo or frame.
  public init?(
    photoWidth: Double, photoHeight: Double, frameWidth: Double, centreY: Double,
    reachTop: Double, reachBottom: Double
  ) {
    guard photoWidth > 0, photoHeight > 0, frameWidth > 0 else { return nil }
    let scale = max(
      frameWidth / photoWidth,
      2 * (centreY - reachTop) / photoHeight,
      2 * (reachBottom - centreY) / photoHeight)
    width = photoWidth * scale
    height = photoHeight * scale
    x = (frameWidth - width) / 2
    y = centreY - height / 2
  }

  /// On a card whose top `band` points are uncovered: centred ``belowMiddle`` under the band's
  /// middle, its top never below the card's, and its bottom far enough under the band that the
  /// fade starts under whatever covers the rest.
  public static func card(photoWidth: Double, photoHeight: Double, width: Double, band: Double)
    -> PhotoPlacement?
  {
    PhotoPlacement(
      photoWidth: photoWidth, photoHeight: photoHeight, frameWidth: width,
      centreY: band / 2 + belowMiddle, reachTop: 0, reachBottom: band + fade)
  }

  /// In a page's head, uncovered from `uncoveredTop` to `uncoveredBottom`: centred
  /// ``belowMiddle`` under that span's middle, with both its fades outside the span.
  public static func hero(
    photoWidth: Double, photoHeight: Double, width: Double, uncoveredTop: Double,
    uncoveredBottom: Double
  ) -> PhotoPlacement? {
    PhotoPlacement(
      photoWidth: photoWidth, photoHeight: photoHeight, frameWidth: width,
      centreY: (uncoveredTop + uncoveredBottom) / 2 + belowMiddle,
      reachTop: uncoveredTop - fade, reachBottom: uncoveredBottom + fade)
  }
}

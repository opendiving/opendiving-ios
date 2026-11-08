import OpenDivingKit
import SwiftUI

/// What a card's backdrop is handed: the card's width and how many points of its foot the
/// details cover, from which a map works out where its pins go.
struct CardBackdropFrame {
  let width: CGFloat
  let coveredBottom: CGFloat

  /// The band of backdrop above the details, the web's.
  static let band: CGFloat = 132
  /// Where a card's pins centre, from its top, unless something drawn over the map needs them
  /// higher: the middle of the band below the credit in its corner.
  static let pinCentre: CGFloat = 80

  /// What a map covers so that its pins fit a band centred `pinCentre` points from the card's
  /// top and as tall as the card's band leaves either side of it.
  func mapCovers(pinCentre: CGFloat = Self.pinCentre) -> (top: CGFloat, bottom: CGFloat) {
    let padding = MapBackdropLayout.fitPadding
    let reach = max(0, min(pinCentre, Self.band - pinCentre) - padding)
    return (
      top: pinCentre - reach - padding,
      bottom: Self.band + coveredBottom - (pinCentre + reach) - padding
    )
  }
}

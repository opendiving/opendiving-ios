import SwiftUI

extension Color {
  /// The web's `--teal`, the CSS named colour #008080, the same in light and dark. The system's
  /// `.teal` is a lighter colour that changes with the appearance. This is the fill, under white
  /// text and in a switch.
  static let brandTeal = Color(red: 0, green: 128 / 255, blue: 128 / 255)

  /// The web's `--coral`, the CSS named colour #FF7F50, the same in light and dark.
  static let brandCoral = Color(red: 1, green: 127 / 255, blue: 80 / 255)

  /// The asset catalog's `AccentColor` as a colour: #008080 in the light and a lighter teal in the
  /// dark, where #008080 is too dim to read.
  static let accentText = Color("AccentColor")

  /// The web's `--destructive`, a dark coral in the light and a light one in the dark, for text and
  /// symbols. Dialogs, menus and alerts stay the system's red, which nothing can reach.
  static let danger = Color(
    UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 1, green: 0.467, blue: 0.36, alpha: 1)
        : UIColor(red: 0.79, green: 0.174, blue: 0.05, alpha: 1)
    })

  /// The web's `--destructive-solid`, the fill under white text in both appearances.
  static let dangerFill = Color(red: 0.752, green: 0.165, blue: 0.048)

  /// A page that opens with a map head: the colour the head's map fades into, so the two meet
  /// without a seam.
  static let pageBackground = Color(.systemBackground)

  /// A card on such a page, set off from it in both appearances.
  static let cardFill = Color(.secondarySystemBackground)

  /// The map's open water, in the colour the web names its sea: under a map, where it has no tile
  /// to draw — past the world's edge, or before the tiles arrive — and in place of one.
  static let mapWater = Color(
    UIColor {
      $0.userInterfaceStyle == .dark
        ? UIColor(red: 68 / 255, green: 108 / 255, blue: 107 / 255, alpha: 1)
        : UIColor(red: 163 / 255, green: 206 / 255, blue: 205 / 255, alpha: 1)
    })
}

import SwiftUI

extension Color {
  /// The web's `--teal`, the CSS named colour #008080, the same in light and dark. The system's
  /// `.teal` is a lighter colour that changes with the appearance. This is the fill, under white
  /// text and in a switch.
  static let brandTeal = Color(red: 0, green: 128 / 255, blue: 128 / 255)

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
}

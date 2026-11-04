import SwiftUI

extension Color {
  /// The web's `--teal`, the CSS named colour #008080, the same in light and dark. The system's
  /// `.teal` is a lighter colour that changes with the appearance. This is the fill, under white
  /// text and in a switch. Tinted text takes the asset catalog's `AccentColor`, which is this in
  /// the light and a lighter teal in the dark, where #008080 is too dim to read.
  static let brandTeal = Color(red: 0, green: 128 / 255, blue: 128 / 255)
}

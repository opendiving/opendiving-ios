import OpenDivingKit
import SwiftUI

extension ProfileChannel {
  /// The web's channel tokens, one colour each and the same in light and dark, so a curve
  /// reads the same colour on the phone as on the web.
  var color: Color {
    switch self {
    case .depth: hsl(180, 100, 25)
    case .ceiling: hsl(0, 80, 55)
    case .temperature: hsl(16, 100, 65.7)
    case .pressure: hsl(220, 6, 52)
    case .ndl: hsl(150, 65, 38)
    case .tts: hsl(35, 95, 40)
    case .ppo2: hsl(205, 85, 45)
    case .cns: hsl(300, 60, 55)
    case .gradientFactor: hsl(95, 55, 35)
    case .surfaceGradientFactor: hsl(230, 70, 62)
    }
  }
}

/// A CSS `hsl()` colour, which is how the web declares the tokens.
private func hsl(_ hue: Double, _ saturation: Double, _ lightness: Double) -> Color {
  let l = lightness / 100
  let chroma = (1 - abs(2 * l - 1)) * saturation / 100
  let sector = hue / 60
  let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
  let (r, g, b): (Double, Double, Double) =
    switch sector {
    case ..<1: (chroma, x, 0)
    case ..<2: (x, chroma, 0)
    case ..<3: (0, chroma, x)
    case ..<4: (0, x, chroma)
    case ..<5: (x, 0, chroma)
    default: (chroma, 0, x)
    }
  let m = l - chroma / 2
  return Color(red: r + m, green: g + m, blue: b + m)
}

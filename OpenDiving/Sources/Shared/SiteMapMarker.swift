import OpenDivingKit
import SwiftUI
import UIKit

/// A site on the site finder's map: a round mark filled in the mark's colour, with the dive-site
/// symbol's two bubbles in it and the outline over it, centred on the point it marks. A soft
/// shadow edges it where the outline meets land as pale as itself; in the dark the fill is deeper
/// and the outline grey, so the marks do not glare.
enum SiteMapMarker {
  /// Points per unit of the symbol's 24-unit grid.
  private static let scale: CGFloat = 1.1
  private static let stroke: CGFloat = 1.5
  /// The mark's circle on the grid: the dive-site symbol's round head.
  private static let center = CGPoint(x: 12, y: 10)
  private static let radius: CGFloat = 8
  /// Moves the symbol's bubbles, which sit low in its head to leave room for the tip, to the
  /// middle of the circle.
  private static let bubbleShift = CGVector(dx: -0.43, dy: -0.72)
  /// Room around the mark for its shadow, in points.
  private static let margin: CGFloat = 3.5

  /// The mark's radius on the map, to the outside of its outline.
  static let outerRadius = (radius + stroke / 2) * scale

  /// The fill a mark takes on the map: the brand's colour, a shade deeper in the dark.
  static func fill(_ mark: DiveSiteMark, dark: Bool) -> UIColor {
    let color = UIColor(mark.color).resolvedColor(
      with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
    guard dark else { return color }
    var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return UIColor(red: red * 0.85, green: green * 0.85, blue: blue * 0.85, alpha: alpha)
  }

  /// The outline of a site and of a group: white, and a light grey in the dark.
  static func edge(dark: Bool) -> UIColor {
    dark ? UIColor(white: 0.8, alpha: 1) : .white
  }

  static let shadow = UIColor.black.withAlphaComponent(0.35)

  static func image(_ mark: DiveSiteMark, dark: Bool) -> UIImage {
    let side = outerRadius * 2 + margin * 2
    return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
      let cg = context.cgContext
      cg.translateBy(x: side / 2, y: side / 2)
      cg.scaleBy(x: scale, y: scale)
      cg.translateBy(x: -center.x, y: -center.y)
      // One layer, so the shape casts a single shadow rather than one per stroke.
      cg.setShadow(offset: CGSize(width: 0, height: 1), blur: 2.5, color: shadow.cgColor)
      cg.beginTransparencyLayer(auxiliaryInfo: nil)
      let outline = UIBezierPath(ovalIn: circle(x: center.x, y: center.y, radius: radius))
      fill(mark, dark: dark).setFill()
      outline.fill()
      edge(dark: dark).set()
      outline.lineWidth = stroke
      outline.stroke()
      cg.translateBy(x: bubbleShift.dx, y: bubbleShift.dy)
      UIBezierPath(ovalIn: circle(x: 9.9, y: 13.74, radius: 2)).fill()
      let bubble = UIBezierPath(ovalIn: circle(x: 14.02, y: 8.64, radius: 2.2))
      bubble.lineWidth = stroke
      bubble.stroke()
      cg.endTransparencyLayer()
    }
  }

  private static func circle(x: CGFloat, y: CGFloat, radius: CGFloat) -> CGRect {
    CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
  }
}

#Preview {
  VStack(spacing: 0) {
    ForEach([false, true], id: \.self) { dark in
      HStack(spacing: 16) {
        ForEach(DiveSiteMark.allCases, id: \.self) {
          Image(uiImage: SiteMapMarker.image($0, dark: dark))
        }
      }
      .padding()
      .frame(maxWidth: .infinity)
      .background(dark ? Color(white: 0.2) : Color(red: 0.96, green: 0.94, blue: 0.85))
    }
  }
}

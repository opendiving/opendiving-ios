import OpenDivingKit
import SwiftUI
import UIKit

/// The site finder's pin: the dive-site symbol with its inside filled in the mark's colour, the
/// outline and the bubbles over it, its tip on the point it marks. A soft shadow edges it where
/// the outline meets land as pale as itself; in the dark the fill is deeper and the outline grey,
/// so the marks do not glare.
enum SiteMapPin {
  /// Points per unit of the symbol's 24-unit grid.
  private static let scale: CGFloat = 1.1
  private static let stroke: CGFloat = 1.5
  /// The part of the grid the pin covers: the outline and the half of its stroke outside it.
  private static let frame = CGRect(x: 3.25, y: 1.25, width: 17.5, height: 21.5)
  /// Room around the pin for its shadow, in points.
  private static let margin: CGFloat = 3.5

  /// How far above the point the middle of the pin's round head stands.
  static let headHeight = (frame.maxY - 10) * scale
  static let headRadius = (8 + stroke / 2) * scale
  /// How far the image is moved down so that its tip, not the shadow under it, is on the point.
  static let tipOffset = margin

  /// The fill a mark takes on the map: the brand's colour, a shade deeper in the dark.
  static func fill(_ mark: DiveSiteMark, dark: Bool) -> UIColor {
    let color = UIColor(mark.color).resolvedColor(
      with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
    guard dark else { return color }
    var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return UIColor(red: red * 0.85, green: green * 0.85, blue: blue * 0.85, alpha: alpha)
  }

  /// The outline of a pin and of a group: white, and a light grey in the dark.
  static func edge(dark: Bool) -> UIColor {
    dark ? UIColor(white: 0.8, alpha: 1) : .white
  }

  static let shadow = UIColor.black.withAlphaComponent(0.35)

  static func image(_ mark: DiveSiteMark, dark: Bool) -> UIImage {
    let size = CGSize(
      width: frame.width * scale + margin * 2, height: frame.height * scale + margin * 2)
    return UIGraphicsImageRenderer(size: size).image { context in
      let cg = context.cgContext
      cg.translateBy(x: margin, y: margin)
      cg.scaleBy(x: scale, y: scale)
      cg.translateBy(x: -frame.minX, y: -frame.minY)
      // One layer, so the shape casts a single shadow rather than one per stroke.
      cg.setShadow(offset: CGSize(width: 0, height: 1), blur: 2.5, color: shadow.cgColor)
      cg.beginTransparencyLayer(auxiliaryInfo: nil)
      let outline = outline()
      fill(mark, dark: dark).setFill()
      outline.fill()
      edge(dark: dark).set()
      outline.lineWidth = stroke
      outline.lineJoinStyle = .round
      outline.stroke()
      UIBezierPath(ovalIn: circle(x: 9.9, y: 13.74, radius: 2)).fill()
      let bubble = UIBezierPath(ovalIn: circle(x: 14.02, y: 8.64, radius: 2.2))
      bubble.lineWidth = stroke
      bubble.stroke()
      cg.endTransparencyLayer()
    }
  }

  /// `dive-site.svg`'s outline: a round head over a tip at (12, 22).
  private static func outline() -> UIBezierPath {
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 20, y: 10))
    path.addCurve(
      to: CGPoint(x: 12.601, y: 21.799), controlPoint1: CGPoint(x: 20, y: 14.993),
      controlPoint2: CGPoint(x: 14.461, y: 20.193))
    let tip = atan2(0.799, 0.601)
    path.addArc(
      withCenter: CGPoint(x: 12, y: 21), radius: 1, startAngle: tip, endAngle: .pi - tip,
      clockwise: true)
    path.addCurve(
      to: CGPoint(x: 4, y: 10), controlPoint1: CGPoint(x: 9.539, y: 20.193),
      controlPoint2: CGPoint(x: 4, y: 14.993))
    path.addArc(
      withCenter: CGPoint(x: 12, y: 10), radius: 8, startAngle: .pi, endAngle: 2 * .pi,
      clockwise: true)
    path.close()
    return path
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
          Image(uiImage: SiteMapPin.image($0, dark: dark))
        }
      }
      .padding()
      .frame(maxWidth: .infinity)
      .background(dark ? Color(white: 0.2) : Color(red: 0.96, green: 0.94, blue: 0.85))
    }
  }
}

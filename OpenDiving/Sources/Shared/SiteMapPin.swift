import OpenDivingKit
import SwiftUI
import UIKit

/// The site finder's pin: the dive-site symbol with its inside filled in the mark's colour, the
/// outline and the bubbles white over it, its tip on the point it marks.
enum SiteMapPin {
  /// Points per unit of the symbol's 24-unit grid.
  private static let scale: CGFloat = 1.1
  private static let stroke: CGFloat = 1.5
  /// The part of the grid the image holds: the outline and the half of its stroke outside it.
  private static let frame = CGRect(x: 3.25, y: 1.25, width: 17.5, height: 21.5)

  /// How far above the point the middle of the pin's round head stands.
  static let headHeight = (frame.maxY - 10) * scale
  static let headRadius = (8 + stroke / 2) * scale

  static func image(_ mark: DiveSiteMark) -> UIImage {
    let size = CGSize(width: frame.width * scale, height: frame.height * scale)
    return UIGraphicsImageRenderer(size: size).image { context in
      context.cgContext.scaleBy(x: scale, y: scale)
      context.cgContext.translateBy(x: -frame.minX, y: -frame.minY)
      let outline = outline()
      UIColor(mark.color).setFill()
      outline.fill()
      UIColor.white.set()
      outline.lineWidth = stroke
      outline.lineJoinStyle = .round
      outline.stroke()
      UIBezierPath(ovalIn: circle(x: 9.9, y: 13.74, radius: 2)).fill()
      let bubble = UIBezierPath(ovalIn: circle(x: 14.02, y: 8.64, radius: 2.2))
      bubble.lineWidth = stroke
      bubble.stroke()
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
  HStack(spacing: 16) {
    ForEach(DiveSiteMark.allCases, id: \.self) { Image(uiImage: SiteMapPin.image($0)) }
  }
  .padding()
  .background(Color(.systemGroupedBackground))
}

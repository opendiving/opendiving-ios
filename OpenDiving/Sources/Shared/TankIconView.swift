import OpenDivingKit
import SwiftUI

/// A cylinder drawn as the web draws it: on Lucide's 24-unit grid, in the foreground colour,
/// over the fills its gas is coloured with. Drawn rather than a symbol because its gas and
/// kind multiply into a dozen drawings, and a symbol takes one colour per layer.
struct TankIconView: View {
  let icon: TankIcon
  var lineWidth: CGFloat = 1.5

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) / 24
      context.translateBy(x: (size.width - 24 * scale) / 2, y: (size.height - 24 * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      let drawing = TankDrawing(icon.kind)
      for cylinder in drawing.cylinders {
        for (part, color) in Self.fills(icon.gas) {
          context.fill(cylinder.intersection(Path(part)), with: .color(color))
        }
      }
      let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
      context.stroke(drawing.lines, with: .foreground, style: style)
    }
    .accessibilityHidden(true)
  }

  // A cylinder's shoulder is above y = 11, its band between 11 and 17, its base below 17.
  private static let shoulder = CGRect(x: 0, y: 0, width: 24, height: 11)
  private static let band = CGRect(x: 0, y: 11, width: 24, height: 6)
  private static let base = CGRect(x: 0, y: 17, width: 24, height: 7)
  private static let whole = CGRect(x: 0, y: 0, width: 24, height: 24)

  // The US medical-gas colours (CGA C-9): oxygen green, helium brown.
  private static let oxygen = Color(hue: 144 / 360, saturation: 1, brightness: 0.78)
  private static let helium = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(hue: 30 / 360, saturation: 1, brightness: 0.88, alpha: 1)
        : UIColor(hue: 25 / 360, saturation: 1, brightness: 0.74, alpha: 1)
    })

  private static func fills(_ gas: TankIcon.Gas) -> [(CGRect, Color)] {
    switch gas {
    case .air: []
    case .nitrox: [(band, oxygen)]
    case .oxygen: [(whole, oxygen)]
    case .trimix: [(shoulder, helium), (base, oxygen)]
    }
  }
}

/// The outlines of one of the three tank drawings, in 24-unit space.
private struct TankDrawing {
  var cylinders: [Path] = []
  var lines = Path()

  init(_ kind: TankIcon.Kind) {
    switch kind {
    case .twin:
      for x: CGFloat in [2, 14] { addCylinder(x) }
      addValve(x: 4)
      addValve(x: 16)
      addLine(8, 3, 16, 3)
      addLine(2, 3, 4, 3)
      addLine(20, 3, 22, 3)
      addLine(2, 11, 22, 11)
      addLine(2, 17, 22, 17)
    case .single:
      addCylinder(5)
      addValve(x: 7)
      addLine(5, 3, 7, 3)
      lines.move(to: CGPoint(x: 11, y: 3))
      lines.addArc(
        tangent1End: CGPoint(x: 17, y: 3), tangent2End: CGPoint(x: 17, y: 9), radius: 6)
      lines.addLine(to: CGPoint(x: 17, y: 16))
      lines.addEllipse(in: CGRect(x: 15, y: 16, width: 4, height: 4))
      addLine(5, 11, 13, 11)
      addLine(5, 17, 13, 17)
    case .left:
      addCylinder(11)
      addValve(x: 13)
      addLine(17, 3, 19, 3)
      lines.move(to: CGPoint(x: 13, y: 3))
      lines.addArc(
        tangent1End: CGPoint(x: 7, y: 3), tangent2End: CGPoint(x: 7, y: 9), radius: 6)
      lines.addEllipse(in: CGRect(x: 5, y: 9, width: 4, height: 4))
      addLine(11, 11, 19, 11)
      addLine(11, 17, 19, 17)
    }
    for cylinder in cylinders { lines.addPath(cylinder) }
  }

  /// A cylinder 8 wide from `x`, its shoulder a half circle from y = 6 and its base at 22.
  private mutating func addCylinder(_ x: CGFloat) {
    let radii = RectangleCornerRadii(
      topLeading: 4, bottomLeading: 2, bottomTrailing: 2, topTrailing: 4)
    cylinders.append(
      UnevenRoundedRectangle(cornerRadii: radii, style: .circular)
        .path(in: CGRect(x: x, y: 6, width: 8, height: 16)))
  }

  /// The valve 4 wide from `x`, rising from the shoulder at 6.5 to its top at 2.
  private mutating func addValve(x: CGFloat) {
    lines.move(to: CGPoint(x: x + 4, y: 6.5))
    lines.addArc(
      tangent1End: CGPoint(x: x + 4, y: 2), tangent2End: CGPoint(x: x, y: 2), radius: 1)
    lines.addArc(tangent1End: CGPoint(x: x, y: 2), tangent2End: CGPoint(x: x, y: 6.5), radius: 1)
    lines.addLine(to: CGPoint(x: x, y: 6.5))
  }

  private mutating func addLine(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
    lines.move(to: CGPoint(x: x1, y: y1))
    lines.addLine(to: CGPoint(x: x2, y: y2))
  }
}

#Preview {
  let gases: [TankIcon.Gas] = [.air, .nitrox, .oxygen, .trimix]
  Grid(horizontalSpacing: 16, verticalSpacing: 16) {
    ForEach([TankIcon.Kind.single, .twin, .left], id: \.self) { kind in
      GridRow {
        ForEach(gases, id: \.self) { gas in
          TankIconView(icon: TankIcon(kind: kind, gas: gas))
            .frame(width: 40, height: 40)
        }
      }
    }
  }
  .padding()
}

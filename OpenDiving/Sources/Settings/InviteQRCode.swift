import CoreImage
import CoreImage.CIFilterBuiltins
import OpenDivingKit
import SwiftUI

/// A QR code of an address, with the brand mark at its centre. Hidden whenever the app is not
/// active, as ``CopyField`` hides its value, so the app switcher's snapshot never holds the link.
struct InviteQRCode: View {
  let address: String
  let label: String

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    Group {
      if scenePhase == .active, let layout = Self.layout(address) {
        InviteQRSymbol(layout: layout)
          .accessibilityElement()
          .accessibilityLabel(label)
          .accessibilityAddTraits(.isImage)
      } else {
        Color(.secondarySystemFill)
          .clipShape(.rect(cornerRadius: 12))
          .accessibilityHidden(true)
      }
    }
    .frame(maxWidth: 256)
    .aspectRatio(1, contentMode: .fit)
  }

  /// The layout of the address's symbol at correction level M, which keeps the flagship's invite
  /// links at version 5, and still recovers the modules the mark leaves out.
  nonisolated static func layout(_ text: String) -> InviteQRLayout? {
    matrix(text).flatMap(InviteQRLayout.init(matrix:))
  }

  /// The symbol's dark modules, read from CoreImage's one pixel a module without the margin it
  /// adds.
  nonisolated static func matrix(_ text: String) -> [[Bool]]? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage,
      let image = CIContext().createCGImage(output, from: output.extent)
    else { return nil }
    let width = image.width
    guard image.height == width,
      let context = CGContext(
        data: nil, width: width, height: width, bitsPerComponent: 8, bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: width))
    guard let data = context.data else { return nil }
    let pixels = data.bindMemory(to: UInt8.self, capacity: width * width)
    let isDark = { (row: Int, column: Int) in pixels[row * width + column] < 128 }
    // The top-left finder's corner is the first dark pixel on the diagonal.
    guard let margin = (0..<width).first(where: { isDark($0, $0) }) else { return nil }
    let size = width - 2 * margin
    guard size > 0 else { return nil }
    return (0..<size).map { row in
      (0..<size).map { isDark(margin + row, margin + $0) }
    }
  }
}

/// The symbol, drawn with its quiet zone. Light: ink modules merged into soft shapes on white,
/// with coral pupils. Dark: light dots on the surface behind it, an inverted symbol, which the
/// iPhone's camera reads, with teal pupils. The mark is coral in both.
struct InviteQRSymbol: View {
  let layout: InviteQRLayout

  @Environment(\.colorScheme) private var colorScheme

  /// The modules of margin the QR specification asks for around the symbol.
  static let quietZone = 4.0

  // Fixed colours rather than the appearance's: a scanner needs this contrast whatever it does.
  // The light pupil is a deeper coral than the brand's, which washes out on white when small.
  private static let lightInk = Color(red: 11 / 255, green: 27 / 255, blue: 43 / 255)
  private static let lightPupil = Color(red: 226 / 255, green: 88 / 255, blue: 45 / 255)
  private static let darkInk = Color(red: 233 / 255, green: 239 / 255, blue: 244 / 255)
  private static let darkPupil = Color(red: 60 / 255, green: 198 / 255, blue: 192 / 255)

  var body: some View {
    let isDark = colorScheme == .dark
    Canvas { context, size in
      let extent = Double(layout.size) + Self.quietZone * 2
      context.scaleBy(x: size.width / extent, y: size.height / extent)
      context.translateBy(x: Self.quietZone, y: Self.quietZone)
      let ink = isDark ? Self.darkInk : Self.lightInk
      context.fill(isDark ? dots : fluidModules, with: .color(ink))
      context.fill(rings, with: .color(ink), style: FillStyle(eoFill: true))
      context.fill(alignmentDots, with: .color(ink))
      context.fill(pupils, with: .color(isDark ? Self.darkPupil : Self.lightPupil))
      if let mark = layout.mark {
        drawMark(mark, in: &context)
      }
    }
    .background(isDark ? Color.clear : .white)
    .clipShape(.rect(cornerRadius: 12))
  }

  private var fluidModules: Path {
    var path = Path()
    for module in layout.drawnModules {
      let corners = layout.roundedCorners(row: module.row, column: module.column)
      let radius = { (corner: InviteQRLayout.Corners) in corners.contains(corner) ? 0.5 : 0 }
      path.addPath(
        UnevenRoundedRectangle(
          topLeadingRadius: radius(.topLeft), bottomLeadingRadius: radius(.bottomLeft),
          bottomTrailingRadius: radius(.bottomRight), topTrailingRadius: radius(.topRight),
          style: .circular
        ).path(in: CGRect(x: module.column, y: module.row, width: 1, height: 1)))
    }
    return path
  }

  private var dots: Path {
    var path = Path()
    for module in layout.drawnModules {
      path.addPath(
        Self.circle(x: Double(module.column) + 0.5, y: Double(module.row) + 0.5, radius: 0.44))
    }
    return path
  }

  /// The finders' outer rings and the alignment patterns' rings, each a shape less its hole.
  private var rings: Path {
    var path = Path()
    for finder in layout.finders {
      let x = Double(finder.column)
      let y = Double(finder.row)
      path.addPath(Self.square(x: x, y: y, side: 7, radius: 2.3))
      path.addPath(Self.square(x: x + 1, y: y + 1, side: 5, radius: 1.5))
    }
    for alignment in layout.alignments {
      let x = Double(alignment.column) - 2
      let y = Double(alignment.row) - 2
      path.addPath(Self.square(x: x, y: y, side: 5, radius: 1.5))
      path.addPath(Self.square(x: x + 1, y: y + 1, side: 3, radius: 0.9))
    }
    return path
  }

  private var alignmentDots: Path {
    var path = Path()
    for alignment in layout.alignments {
      path.addPath(
        Self.circle(x: Double(alignment.column) + 0.5, y: Double(alignment.row) + 0.5, radius: 0.55)
      )
    }
    return path
  }

  private var pupils: Path {
    var path = Path()
    for finder in layout.finders {
      path.addPath(
        Self.square(x: Double(finder.column) + 2, y: Double(finder.row) + 2, side: 3, radius: 1))
    }
    return path
  }

  private func drawMark(_ mark: InviteQRLayout.Mark, in context: inout GraphicsContext) {
    var outlines = Path()
    var filled = Path()
    for (index, bubble) in InviteQRLayout.markBubbles.enumerated() {
      let circle = Self.circle(
        x: mark.offset + bubble.x * mark.scale, y: mark.offset + bubble.y * mark.scale,
        radius: bubble.radius * mark.scale)
      outlines.addPath(circle)
      if index == 0 { filled.addPath(circle) }
    }
    context.fill(filled, with: .color(.brandCoral))
    context.stroke(
      outlines, with: .color(.brandCoral),
      style: StrokeStyle(lineWidth: InviteQRLayout.markStroke * mark.scale, lineCap: .round))
  }

  private static func square(x: Double, y: Double, side: Double, radius: Double) -> Path {
    Path(
      roundedRect: CGRect(x: x, y: y, width: side, height: side), cornerRadius: radius,
      style: .circular)
  }

  private static func circle(x: Double, y: Double, radius: Double) -> Path {
    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
  }
}

#Preview {
  InviteQRCode(
    address: "https://opendiving.app/join?via=q7Zr2LmW-exampleInviteTokenNot_Real01234567",
    label: "QR code of your invite link")
}

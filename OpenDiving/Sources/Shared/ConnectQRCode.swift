import CoreImage
import CoreImage.CIFilterBuiltins
import OpenDivingKit
import SwiftUI
import UIKit

/// A QR code of an address, with the brand mark at its centre. Whenever the app is not active a
/// blurred symbol of a stand-in address of the same length takes its place, as ``CopyField``
/// hides its value, so the app switcher's snapshot never holds the link.
struct ConnectQRCode: View {
  let address: String
  let label: String

  @State private var isShielded = UIApplication.shared.applicationState != .active
  /// In the background, where the system snapshots the app: the code leaves at once, whatever
  /// its blur has reached.
  @State private var isAway = UIApplication.shared.applicationState == .background

  private static let fade = Animation.easeInOut(duration: 0.25)

  var body: some View {
    ZStack {
      if let layout = Self.cachedLayout(Self.standIn(for: address)) {
        ConnectQRSymbol(layout: layout)
          .blur(radius: 8)
          .clipShape(.rect(cornerRadius: 12))
          .opacity(isShielded ? 1 : 0)
          .animation(Self.fade, value: isShielded)
          .accessibilityHidden(true)
      }
      if !isAway, let layout = Self.cachedLayout(address) {
        // Blurred out under the stand-in, which reads as the code itself blurring.
        ConnectQRSymbol(layout: layout)
          .blur(radius: isShielded ? 8 : 0)
          .clipShape(.rect(cornerRadius: 12))
          .opacity(isShielded ? 0 : 1)
          .animation(Self.fade, value: isShielded)
          .accessibilityElement()
          .accessibilityLabel(label)
          .accessibilityAddTraits(.isImage)
          .accessibilityHidden(isShielded)
      }
    }
    // Square before the cap: a canvas has no shape of its own and fills whatever it is offered.
    .aspectRatio(1, contentMode: .fit)
    .frame(maxWidth: 256)
    // The scene's own notices rather than `scenePhase`, which can reach the view only after the
    // switcher has drawn the app's card.
    .onReceive(NotificationCenter.default.publisher(for: UIScene.willDeactivateNotification)) {
      _ in isShielded = true
    }
    .onReceive(NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)) {
      _ in isAway = true
    }
    .onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)) {
      _ in isAway = false
    }
    .onReceive(NotificationCenter.default.publisher(for: UIScene.didActivateNotification)) {
      _ in isShielded = false
    }
  }

  private static var layouts: [String: ConnectQRLayout] = [:]

  /// `layout(_:)`, kept: the code and its stand-in are drawn again on every change of state.
  private static func cachedLayout(_ text: String) -> ConnectQRLayout? {
    if let layout = layouts[text] { return layout }
    let layout = Self.layout(text)
    layouts[text] = layout
    return layout
  }

  /// An address of `address`'s length, whose symbol is the size of its own.
  nonisolated static func standIn(for address: String) -> String {
    String(repeating: "x", count: address.count)
  }

  /// The layout of the address's symbol at correction level Q, which recovers the modules the
  /// mark leaves out with room to spare and keeps the flagship's connect links below version 7,
  /// where the mark has no room.
  nonisolated static func layout(_ text: String) -> ConnectQRLayout? {
    matrix(text).flatMap(ConnectQRLayout.init(matrix:))
  }

  /// The symbol's dark modules, read from CoreImage's one pixel a module without the margin it
  /// adds.
  nonisolated static func matrix(_ text: String) -> [[Bool]]? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "Q"
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

/// The symbol, drawn with its quiet zone on the surface behind it. Light: ink modules merged
/// into soft shapes, with coral pupils. Dark: light dots, an inverted symbol, which the iPhone's
/// camera reads, with teal pupils. The mark is coral in both.
struct ConnectQRSymbol: View {
  let layout: ConnectQRLayout

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
      let unit = size.width / extent
      let ink = isDark ? Self.darkInk : Self.lightInk
      let pupil = isDark ? Self.darkPupil : Self.lightPupil
      var code = context
      code.scaleBy(x: unit, y: unit)
      code.translateBy(x: Self.quietZone, y: Self.quietZone)
      code.fill(isDark ? dotsPath : fluidModules, with: .color(ink))
      code.fill(alignmentRings, with: .color(ink), style: FillStyle(eoFill: true))
      code.fill(alignmentDots, with: .color(ink))
      if let mark = layout.mark {
        drawMark(mark, in: &code)
      }

      // Each finder, 7 modules a side: a rounded ring round a rounded pupil.
      var rings = Path()
      var pupils = Path()
      for finder in layout.finders {
        let outer = CGRect(x: finder.column, y: finder.row, width: 7, height: 7)
        rings.addPath(Self.rounded(outer, radius: 2.3))
        rings.addPath(Self.rounded(outer.insetBy(dx: 1, dy: 1), radius: 1.5))
        pupils.addPath(Self.rounded(outer.insetBy(dx: 2, dy: 2), radius: 1))
      }
      code.fill(rings, with: .color(ink), style: FillStyle(eoFill: true))
      code.fill(pupils, with: .color(pupil))
    }
    .clipShape(.rect(cornerRadius: 12))
  }

  private var fluidModules: Path {
    var path = Path()
    for module in layout.drawnModules {
      let corners = layout.roundedCorners(row: module.row, column: module.column)
      let radius = { (corner: ConnectQRLayout.Corners) in corners.contains(corner) ? 0.5 : 0 }
      path.addPath(
        UnevenRoundedRectangle(
          topLeadingRadius: radius(.topLeft), bottomLeadingRadius: radius(.bottomLeft),
          bottomTrailingRadius: radius(.bottomRight), topTrailingRadius: radius(.topRight),
          style: .circular
        ).path(in: CGRect(x: module.column, y: module.row, width: 1, height: 1)))
    }
    return path
  }

  private var dotsPath: Path {
    var path = Path()
    for module in layout.drawnModules {
      path.addPath(
        Self.circle(x: Double(module.column) + 0.5, y: Double(module.row) + 0.5, radius: 0.44))
    }
    return path
  }

  /// The alignment patterns' rings, each a shape less its hole; the finders are drawn apart.
  private var alignmentRings: Path {
    var path = Path()
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

  private func drawMark(_ mark: ConnectQRLayout.Mark, in context: inout GraphicsContext) {
    var outlines = Path()
    var filled = Path()
    for (index, bubble) in ConnectQRLayout.markBubbles.enumerated() {
      let circle = Self.circle(
        x: mark.offset + bubble.x * mark.scale, y: mark.offset + bubble.y * mark.scale,
        radius: bubble.radius * mark.scale)
      outlines.addPath(circle)
      if index == 0 { filled.addPath(circle) }
    }
    context.fill(filled, with: .color(.brandCoral))
    context.stroke(
      outlines, with: .color(.brandCoral),
      style: StrokeStyle(lineWidth: ConnectQRLayout.markStroke * mark.scale, lineCap: .round))
  }

  private static func square(x: Double, y: Double, side: Double, radius: Double) -> Path {
    Path(
      roundedRect: CGRect(x: x, y: y, width: side, height: side), cornerRadius: radius,
      style: .circular)
  }

  private static func rounded(_ rect: CGRect, radius: Double) -> Path {
    Path(roundedRect: rect, cornerRadius: min(radius, rect.width / 2), style: .circular)
  }

  private static func circle(x: Double, y: Double, radius: Double) -> Path {
    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
  }
}

#Preview {
  ConnectQRCode(
    address: "https://opendiving.app/connect/dd61596d15ae703e0aa5a28b92586efd",
    label: "QR code of your connect link")
}

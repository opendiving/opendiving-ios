import CoreImage
import CoreImage.CIFilterBuiltins
import OpenDivingKit
import SwiftUI
import UIKit

/// A QR code of an address, with the brand mark at its centre. Whenever the app is not active a
/// blurred symbol of a stand-in address of the same length takes its place, as ``CopyField``
/// hides its value, so the app switcher's snapshot never holds the link.
struct InviteQRCode: View {
  let address: String
  let label: String
  /// How far the code has folded into its icon: 0 the code, 1 the icon.
  var morph = 0.0

  @State private var isShielded = UIApplication.shared.applicationState != .active
  /// In the background, where the system snapshots the app: the code leaves at once, whatever
  /// its blur has reached.
  @State private var isAway = UIApplication.shared.applicationState == .background

  private static let fade = Animation.easeInOut(duration: 0.25)

  var body: some View {
    ZStack {
      if let layout = Self.cachedLayout(Self.standIn(for: address)) {
        InviteQRSymbol(layout: layout, morph: morph)
          .blur(radius: 8)
          .clipShape(.rect(cornerRadius: 12 * (1 - morph)))
          .opacity(isShielded ? 1 : 0)
          .animation(Self.fade, value: isShielded)
          .accessibilityHidden(true)
      }
      if !isAway, let layout = Self.cachedLayout(address) {
        // Blurred out under the stand-in, which reads as the code itself blurring.
        InviteQRSymbol(layout: layout, morph: morph)
          .blur(radius: isShielded ? 8 : 0)
          .clipShape(.rect(cornerRadius: 12 * (1 - morph)))
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

  private static var layouts: [String: InviteQRLayout] = [:]

  /// `layout(_:)`, kept: a code folding into its icon draws every frame.
  private static func cachedLayout(_ text: String) -> InviteQRLayout? {
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
  /// mark leaves out with room to spare and keeps the flagship's invite links below version 7,
  /// where the mark has no room.
  nonisolated static func layout(_ text: String) -> InviteQRLayout? {
    matrix(text).flatMap(InviteQRLayout.init(matrix:))
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

/// The symbol, drawn with its quiet zone. Light: ink modules merged into soft shapes on white,
/// with coral pupils. Dark: light dots on the surface behind it, an inverted symbol, which the
/// iPhone's camera reads, with teal pupils. The mark is coral in both.
///
/// Folding into its icon (`morph` above 0), the finders shrink into the icon's eyes and five of
/// the bottom-right quarter's modules into its dots, in ink, while the rest of the code, the
/// pupils' colour and the white behind it fade.
struct InviteQRSymbol: View {
  let layout: InviteQRLayout
  var morph = 0.0

  @Environment(\.colorScheme) private var colorScheme

  /// The modules of margin the QR specification asks for around the symbol.
  static let quietZone = 4.0

  // Fixed colours rather than the appearance's: a scanner needs this contrast whatever it does.
  // The light pupil is a deeper coral than the brand's, which washes out on white when small.
  private static let lightInk = Color(red: 11 / 255, green: 27 / 255, blue: 43 / 255)
  private static let lightPupil = Color(red: 226 / 255, green: 88 / 255, blue: 45 / 255)
  private static let darkInk = Color(red: 233 / 255, green: 239 / 255, blue: 244 / 255)
  private static let darkPupil = Color(red: 60 / 255, green: 198 / 255, blue: 192 / 255)

  static func ink(dark: Bool) -> Color { dark ? darkInk : lightInk }

  var body: some View {
    let isDark = colorScheme == .dark
    let dots = morph > 0 ? layout.iconDotModules : []
    let moving = Set(dots.compactMap(\.self))
    Canvas { context, size in
      let extent = Double(layout.size) + Self.quietZone * 2
      let unit = size.width / extent
      let ink = Self.ink(dark: isDark)
      let pupil = isDark ? Self.darkPupil : Self.lightPupil
      // What only the code has fades over the first part of the fold.
      var code = context
      code.opacity = max(1 - morph * 2.5, 0)
      code.scaleBy(x: unit, y: unit)
      code.translateBy(x: Self.quietZone, y: Self.quietZone)
      code.fill(
        isDark ? dotsPath(skipping: moving) : fluidModules(skipping: moving), with: .color(ink))
      code.fill(alignmentRings, with: .color(ink), style: FillStyle(eoFill: true))
      code.fill(alignmentDots, with: .color(ink))
      if let mark = layout.mark {
        drawMark(mark, in: &code)
      }

      let place = {
        (row: Double, column: Double, side: Double, icon: (x: Double, y: Double), iconSide: Double)
        in
        Self.mix(
          CGRect(
            x: (column + Self.quietZone) * unit, y: (row + Self.quietZone) * unit,
            width: side * unit, height: side * unit),
          CGRect(
            x: icon.x * size.width, y: icon.y * size.height, width: iconSide * size.width,
            height: iconSide * size.height),
          morph)
      }
      // The code's finders, 7 modules a side, give way to the icon's proportions.
      let ring = Self.mix(1 / 7, InviteQRLayout.iconRingWidth, morph)
      let pupilSide = Self.mix(3 / 7, InviteQRLayout.iconPupilSide, morph)
      let outerRadius = Self.mix(2.3 / 7, InviteQRLayout.iconEyeRadius, morph)
      let holeRadius = Self.mix(1.5 / 7, InviteQRLayout.iconHoleRadius, morph)
      let pupilRadius = Self.mix(1 / 7, InviteQRLayout.iconPupilRadius, morph)
      var rings = Path()
      var pupils = Path()
      for (finder, eye) in zip(layout.finders, InviteQRLayout.iconEyes) {
        let outer = place(
          Double(finder.row), Double(finder.column), 7, eye, InviteQRLayout.iconEyeSide)
        let side = outer.width
        let hole = outer.insetBy(dx: side * ring, dy: side * ring)
        let pupilInset = side * (1 - pupilSide) / 2
        rings.addPath(Self.rounded(outer, radius: side * outerRadius))
        rings.addPath(Self.rounded(hole, radius: side * holeRadius))
        pupils.addPath(
          Self.rounded(outer.insetBy(dx: pupilInset, dy: pupilInset), radius: side * pupilRadius))
      }
      context.fill(rings, with: .color(ink), style: FillStyle(eoFill: true))
      context.fill(pupils, with: .color(pupil.mix(with: ink, by: morph)))

      var iconDots = Path()
      for (module, dot) in zip(dots, InviteQRLayout.iconDots) {
        let to = CGRect(
          x: dot.x * size.width, y: dot.y * size.height,
          width: InviteQRLayout.iconDotSide * size.width,
          height: InviteQRLayout.iconDotSide * size.height)
        // A dot the quarter has no module for grows in where it sits.
        let from =
          module.map {
            CGRect(
              x: (Double($0.column) + Self.quietZone) * unit,
              y: (Double($0.row) + Self.quietZone) * unit, width: unit, height: unit)
          } ?? CGRect(x: to.midX, y: to.midY, width: 0, height: 0)
        let rect = Self.mix(from, to, morph)
        let radius =
          rect.width * Self.mix(isDark ? 0.44 : 0.25, InviteQRLayout.iconDotRadius, morph)
        iconDots.addPath(Self.rounded(rect, radius: radius))
      }
      context.fill(iconDots, with: .color(ink))
    }
    .background(isDark ? Color.clear : Color.white.opacity(1 - morph))
    .clipShape(.rect(cornerRadius: 12 * (1 - morph)))
  }

  private func fluidModules(skipping moving: Set<InviteQRLayout.Module>) -> Path {
    var path = Path()
    for module in layout.drawnModules where !moving.contains(module) {
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

  private func dotsPath(skipping moving: Set<InviteQRLayout.Module>) -> Path {
    var path = Path()
    for module in layout.drawnModules where !moving.contains(module) {
      path.addPath(
        Self.circle(x: Double(module.column) + 0.5, y: Double(module.row) + 0.5, radius: 0.44))
    }
    return path
  }

  /// The alignment patterns' rings, each a shape less its hole; the finders are drawn apart, as
  /// they become the icon's eyes.
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

  private static func rounded(_ rect: CGRect, radius: Double) -> Path {
    Path(roundedRect: rect, cornerRadius: min(radius, rect.width / 2), style: .circular)
  }

  private static func mix(_ from: Double, _ to: Double, _ share: Double) -> Double {
    from + (to - from) * share
  }

  private static func mix(_ from: CGRect, _ to: CGRect, _ share: Double) -> CGRect {
    let mix = { (a: Double, b: Double) in a + (b - a) * share }
    return CGRect(
      x: mix(from.minX, to.minX), y: mix(from.minY, to.minY),
      width: mix(from.width, to.width), height: mix(from.height, to.height))
  }

  private static func circle(x: Double, y: Double, radius: Double) -> Path {
    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
  }
}

#Preview {
  InviteQRCode(
    address: "https://opendiving.app/join?via=dd61596d15ae703e0aa5a28b92586efd",
    label: "QR code of your invite link")
}

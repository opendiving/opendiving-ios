import SwiftUI

/// The OpenDiving Commons mark with its name on two lines to its right, the mark's bubbles as tall
/// as the two lines. It tells a page that morphs it where its mark and *Commons* are drawn.
struct CommonsWordmarkHeader: View {
  /// Scaled with the text size up to where the pair still fits a phone's width.
  @ScaledMetric private var height: CGFloat
  private let baseHeight: CGFloat
  /// The name of the coordinate space the frames are given in.
  private let space: String
  private let onMarkFrame: (CGRect) -> Void
  private let onWordFrame: (CGRect) -> Void

  init(
    height: CGFloat = 80, in space: String = "CommonsWordmarkHeader",
    onMarkFrame: @escaping (CGRect) -> Void = { _ in },
    onWordFrame: @escaping (CGRect) -> Void = { _ in }
  ) {
    baseHeight = height
    _height = ScaledMetric(wrappedValue: height, relativeTo: .title)
    self.space = space
    self.onMarkFrame = onMarkFrame
    self.onWordFrame = onWordFrame
  }

  var body: some View {
    let space = space
    HStack(spacing: 6) {
      CommonsMark(side: baseHeight * CommonsName.markScale, relativeTo: .title)
        .onGeometryChange(for: CGRect.self) {
          $0.frame(in: .named(space))
        } action: {
          onMarkFrame($0)
        }
      CommonsName(height: height, space: space, onWordFrame: onWordFrame)
    }
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    .frame(maxWidth: .infinity)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("OpenDiving Commons")
    .accessibilityAddTraits(.isHeader)
  }
}

/// *OpenDiving* over *Commons*, left-aligned and set as one block, `height` tall.
struct CommonsName: View {
  let height: CGFloat
  /// The name of the coordinate space *Commons*'s frame is given in.
  var space = "CommonsName"
  var onWordFrame: (CGRect) -> Void = { _ in }

  // The block in the outlines' font units: each image is its line's ink, so these place them as
  // the two lines set at a line height of one em. Outfit Bold, the web's wordmark face, drawn as
  // outlines because the app carries no copy of the font.
  static let blockWidth: CGFloat = 5314
  static let blockHeight: CGFloat = 1733
  static let openDivingHeight: CGFloat = 939
  static let commonsWidth: CGFloat = 4495
  static let commonsHeight: CGFloat = 729
  static let commonsTop: CGFloat = 1004
  /// The bubbles fill 20 of the mark's 24 units across its height, so a mark this much taller than
  /// a name draws them as tall as it is.
  static let markScale: CGFloat = 1.2

  /// *OpenDiving*'s frame when *Commons* is drawn in `word`.
  static func openDivingFrame(commons word: CGRect) -> CGRect {
    let unit = word.height / commonsHeight
    return CGRect(
      x: word.minX, y: word.minY - commonsTop * unit, width: blockWidth * unit,
      height: openDivingHeight * unit)
  }

  var body: some View {
    let unit = height / Self.blockHeight
    let space = space
    ZStack(alignment: .topLeading) {
      Image("Wordmark")
        .resizable()
        .frame(width: Self.blockWidth * unit, height: Self.openDivingHeight * unit)
      Image("CommonsWord")
        .resizable()
        .frame(width: Self.commonsWidth * unit, height: Self.commonsHeight * unit)
        .onGeometryChange(for: CGRect.self) {
          $0.frame(in: .named(space))
        } action: {
          onWordFrame($0)
        }
        .padding(.top, Self.commonsTop * unit)
    }
    .frame(width: Self.blockWidth * unit, height: height, alignment: .topLeading)
    .foregroundStyle(Color.primary.opacity(0.75))
  }
}

#Preview {
  VStack(spacing: 32) {
    CommonsWordmarkHeader()
    CommonsWordmarkHeader(height: 64)
  }
  .padding()
}

import SwiftUI

/// The OpenDiving Commons logo heading a page, its mark's bubbles `height` points from top to
/// bottom. It tells a page that morphs it where the logo is drawn.
struct CommonsWordmarkHeader: View {
  @ScaledMetric private var height: CGFloat
  private let baseHeight: CGFloat
  /// The name of the coordinate space the frame is given in.
  private let space: String
  private let onLogoFrame: (CGRect) -> Void

  init(
    height: CGFloat = 64, in space: String = "CommonsWordmarkHeader",
    onLogoFrame: @escaping (CGRect) -> Void = { _ in }
  ) {
    baseHeight = height
    _height = ScaledMetric(wrappedValue: height, relativeTo: .title)
    self.space = space
    self.onLogoFrame = onLogoFrame
  }

  var body: some View {
    // Scaled with the text size up to where the logo still fits a phone's width.
    let scale = min(height, baseHeight * 1.3) / CommonsLogo.markHeight
    let space = space
    CommonsLogoLayers(
      size: CGSize(
        width: CommonsLogo.frame.width * scale, height: CommonsLogo.frame.height * scale)
    )
    .onGeometryChange(for: CGRect.self) {
      $0.frame(in: .named(space))
    } action: {
      onLogoFrame($0)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("OpenDiving Commons")
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  CommonsWordmarkHeader()
    .padding()
}

import SwiftUI

/// The OpenDiving Commons logo, its layers on one frame: the mark's filled bubble with a coral C
/// where its bottom-right bubble was, a coral O where its top bubble was, and the rest of each word.
/// The outlines are variable Outfit, the web's wordmark face, which the app carries no copy of:
/// the O at weight 605 and the C at 728, each as tall as the bubble it stands for and as thick as its
/// ring, *penDiving* at 555 and *ommons* at 648, which gives the two the same stem; the C is turned
/// 22° anticlockwise about its bubble's centre.
enum CommonsLogo {
  /// The frame every layer is drawn on, in the outlines' units, a hundredth of the mark's 24-unit
  /// grid.
  static let frame = CGRect(x: -870, y: -999, width: 8435, height: 1999)
  /// The filled bubble, the C and *ommons*: the part that becomes the navigation bar's title.
  static let bar = CGRect(x: -870, y: -68, width: 6960, height: 1068)
  /// The units across the mark's three bubbles, top to bottom: a logo `height` points tall is drawn
  /// at `height / markHeight` points a unit.
  static let markHeight: CGFloat = 2000

  /// Where the bar's part stands in a logo drawn in `logo`.
  static func barFrame(in logo: CGRect) -> CGRect {
    let scale = logo.width / frame.width
    return CGRect(
      x: logo.minX + (bar.minX - frame.minX) * scale,
      y: logo.minY + (bar.minY - frame.minY) * scale,
      width: bar.width * scale, height: bar.height * scale)
  }

  /// The logo whose bar's part stands in `rect`.
  static func frame(barAt rect: CGRect) -> CGRect {
    let scale = rect.width / bar.width
    return CGRect(
      x: rect.minX - (bar.minX - frame.minX) * scale,
      y: rect.minY - (bar.minY - frame.minY) * scale,
      width: frame.width * scale, height: frame.height * scale)
  }
}

/// The logo's layers at `size`, *OpenDiving* at `openDiving`'s opacity: the page head draws it
/// whole, and the head flying into the bar fades it.
struct CommonsLogoLayers: View {
  let size: CGSize
  var openDiving: Double = 1

  var body: some View {
    ZStack {
      layer("CommonsLogoO").opacity(openDiving)
      layer("CommonsLogoPenDiving").foregroundStyle(Color.commonsLogoInk).opacity(openDiving)
      layer("CommonsLogoMark")
      layer("CommonsLogoOmmons").foregroundStyle(Color.commonsLogoInk)
    }
    .frame(width: size.width, height: size.height)
  }

  private func layer(_ name: String) -> some View {
    Image(name).resizable().frame(width: size.width, height: size.height)
  }
}

extension Color {
  /// The logo's letters other than its coral O and C, as the sign-in screen's wordmark is drawn.
  static let commonsLogoInk = Color.primary.opacity(0.75)
}

#Preview {
  CommonsLogoLayers(
    size: CGSize(width: CommonsLogo.frame.width * 0.032, height: CommonsLogo.frame.height * 0.032)
  )
  .padding()
}

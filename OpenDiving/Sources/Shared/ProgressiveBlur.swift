import SwiftUI
import UIKit

/// A blur that grows towards one edge, as Maps draws under the status bar: the radius rises along
/// the fade, with no tint. A material faded by its opacity instead crossfades the sharp content
/// with a grey veil, and only blurs where it is nearly opaque.
///
/// The radius is varied by Core Animation's `variableBlur` filter on a backdrop layer, which the
/// system's own progressive blurs use and the SDK does not expose; where either cannot be made,
/// the faded material stands in.
struct ProgressiveBlur: View {
  /// Where the blur is strongest; it fades to nothing at the opposite edge.
  let edge: VerticalEdge
  /// The radius at `edge`, in points.
  var radius: Double = 12
  /// How much of the height, from `edge`, holds the full radius before the fade starts.
  var hold: Double = 0

  var body: some View {
    Group {
      if VariableBlurView.isAvailable {
        VariableBlurRepresentable(edge: edge, radius: radius, hold: hold)
      } else {
        Rectangle()
          .fill(.thinMaterial)
          .mask {
            LinearGradient(
              stops: [.init(color: .black, location: hold), .init(color: .clear, location: 1)],
              startPoint: edge == .top ? .top : .bottom,
              endPoint: edge == .top ? .bottom : .top)
          }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct VariableBlurRepresentable: UIViewRepresentable {
  let edge: VerticalEdge
  let radius: Double
  let hold: Double

  func makeUIView(context: Context) -> VariableBlurView {
    VariableBlurView()
  }

  func updateUIView(_ view: VariableBlurView, context: Context) {
    view.configure(edge: edge, radius: radius, hold: hold)
  }
}

private final class VariableBlurView: UIView {
  private static let backdropLayer: AnyClass? = NSClassFromString("CABackdropLayer")
  private static let filterClass = NSClassFromString("CAFilter") as? NSObject.Type

  static let isAvailable = backdropLayer != nil && makeFilter() != nil

  override class var layerClass: AnyClass { backdropLayer ?? CALayer.self }

  private var shown: (edge: VerticalEdge, radius: Double, hold: Double)?

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
  }

  required init?(coder: NSCoder) { nil }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    // A backdrop layer samples at 1× unless told the screen's scale, which pixelates the fade's
    // sharp end.
    if let window { layer.setValue(window.traitCollection.displayScale, forKey: "scale") }
  }

  func configure(edge: VerticalEdge, radius: Double, hold: Double) {
    if let shown, shown == (edge, radius, hold) { return }
    shown = (edge, radius, hold)
    guard let filter = Self.makeFilter() else { return }
    filter.setValue(radius, forKey: "inputRadius")
    filter.setValue(Self.mask(edge: edge, hold: hold), forKey: "inputMaskImage")
    // Without it, the edges of the blur darken where it samples past the layer.
    filter.setValue(true, forKey: "inputNormalizeEdges")
    layer.filters = [filter]
  }

  private static func makeFilter() -> NSObject? {
    filterClass?
      .perform(NSSelectorFromString("filterWithType:"), with: "variableBlur")?
      .takeUnretainedValue() as? NSObject
  }

  /// Opaque where the radius is full, clear where there is no blur; the filter stretches it over
  /// the layer. Eased, so the blur does not end on a visible line.
  private static func mask(edge: VerticalEdge, hold: Double) -> CGImage? {
    let height = 64
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: height), format: format)
      .image { context in
        for row in 0..<height {
          let fromEdge = Double(edge == .top ? row : height - 1 - row) / Double(height - 1)
          let fade = max(0, min(1, (fromEdge - hold) / max(1 - hold, 0.001)))
          let alpha = 1 - fade * fade * (3 - 2 * fade)
          UIColor(white: 0, alpha: alpha).setFill()
          context.fill(CGRect(x: 0, y: row, width: 1, height: 1))
        }
      }
    return image.cgImage
  }
}

#Preview {
  ZStack(alignment: .top) {
    LinearGradient(colors: [.teal, .orange], startPoint: .leading, endPoint: .trailing)
      .overlay {
        VStack(spacing: 8) {
          ForEach(0..<30) { Text("Gulf of Aqaba \($0)").frame(maxWidth: .infinity) }
        }
      }
    ProgressiveBlur(edge: .top, radius: 12, hold: 0.3).frame(height: 160)
  }
  .ignoresSafeArea()
}

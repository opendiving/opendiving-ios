import SwiftUI
import UIKit

/// A blur of what lies behind, lighter than any material: a blur view whose effect is stopped part
/// of the way in, which is the one way UIKit draws a blur short of its own.
struct BackdropBlur: UIViewRepresentable {
  /// 0 is no blur, 1 the system's regular one.
  let amount: CGFloat

  func makeUIView(context: Context) -> UIVisualEffectView {
    let view = UIVisualEffectView(effect: nil)
    let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
      view.effect = UIBlurEffect(style: .regular)
    }
    // Held, never run: its fraction is how far in the blur is.
    animator.pausesOnCompletion = true
    animator.fractionComplete = amount
    context.coordinator.animator = animator
    return view
  }

  func updateUIView(_ view: UIVisualEffectView, context: Context) {
    context.coordinator.animator?.fractionComplete = amount
  }

  static func dismantleUIView(_ view: UIVisualEffectView, coordinator: Coordinator) {
    // A paused animator released unstopped is a crash.
    coordinator.animator?.stopAnimation(true)
    coordinator.animator = nil
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var animator: UIViewPropertyAnimator?
  }
}

#Preview {
  ZStack {
    VStack(alignment: .leading) {
      ForEach(0..<20) { Text("Confined Water Training Area \($0)").font(.title3) }
    }
    BackdropBlur(amount: 0.3)
      .ignoresSafeArea()
  }
}

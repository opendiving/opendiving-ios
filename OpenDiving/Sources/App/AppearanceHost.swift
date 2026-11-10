import OpenDivingKit
import SwiftUI
import UIKit

extension View {
  /// Draws the whole window in the diver's appearance — every screen, sheet, alert and map, the
  /// sign-in screens included — with the model in the environment for the screen that picks it.
  /// Set on the window rather than as a preferred colour scheme, which a sheet and a UIKit map
  /// do not reliably follow back to the phone's own.
  func appearanceHost(_ appearance: AppearanceModel) -> some View {
    modifier(AppearanceHost(appearance: appearance))
  }
}

/// A modifier of its own, so the choice is read in a body that follows it.
private struct AppearanceHost: ViewModifier {
  let appearance: AppearanceModel

  func body(content: Content) -> some View {
    content
      .environment(appearance)
      .background(WindowStyle(style: appearance.choice.interfaceStyle).accessibilityHidden(true))
  }
}

extension Appearance {
  fileprivate var interfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .light: .light
    case .dark: .dark
    case .system: .unspecified
    }
  }
}

/// Sets the style on every window of the scene it is placed in, as soon as it has one.
private struct WindowStyle: UIViewRepresentable {
  let style: UIUserInterfaceStyle

  func makeUIView(context: Context) -> StyleView {
    StyleView()
  }

  func updateUIView(_ view: StyleView, context: Context) {
    view.style = style
  }

  final class StyleView: UIView {
    var style = UIUserInterfaceStyle.unspecified {
      didSet { apply() }
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      apply()
    }

    private func apply() {
      for window in window?.windowScene?.windows ?? [] {
        window.overrideUserInterfaceStyle = style
      }
    }
  }
}

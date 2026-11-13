import SwiftUI
import UIKit

/// A clear button laid over a view, opening its menu out of the view's foot — the part from
/// `menuTop` down — wherever on it the tap lands. SwiftUI's `Menu` cannot: it grows the menu out of
/// the whole of its label, which over a tall one covers what was tapped.
struct AnchoredMenuButton: UIViewRepresentable {
  struct Item {
    let title: String
    let systemImage: String
    var destructive = false
    let action: () -> Void
  }

  let items: [Item]
  let accessibilityLabel: String
  let menuTop: CGFloat

  func makeUIView(context: Context) -> Container {
    Container()
  }

  func updateUIView(_ container: Container, context: Context) {
    container.menuTop = menuTop
    let button = container.button
    button.isEnabled = context.environment.isEnabled
    button.accessibilityLabel = accessibilityLabel
    button.menu = UIMenu(
      children: items.map { item in
        UIAction(
          title: item.title, image: UIImage(systemName: item.systemImage),
          attributes: item.destructive ? .destructive : []
        ) { _ in item.action() }
      })
  }

  /// Covers the whole view and hands every touch on it to a button covering only the foot, which
  /// the menu then grows out of.
  final class Container: UIView {
    let button = Button()
    var menuTop: CGFloat = 0 {
      didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
      super.init(frame: frame)
      button.showsMenuAsPrimaryAction = true
      addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
      super.layoutSubviews()
      let top = min(menuTop, bounds.height)
      button.frame = CGRect(x: 0, y: top, width: bounds.width, height: bounds.height - top)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      guard button.isEnabled, self.point(inside: point, with: event) else { return nil }
      return button
    }
  }

  /// Counts the whole container as inside, so a touch above the button still opens its menu.
  final class Button: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
      guard let container = superview else { return super.point(inside: point, with: event) }
      return container.point(inside: convert(point, to: container), with: event)
    }
  }
}

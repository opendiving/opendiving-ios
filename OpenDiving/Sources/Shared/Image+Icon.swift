import OpenDivingKit
import SwiftUI

// `Icon` inside a `Label` extension is the label's own generic parameter, hence the module
// prefix.

extension Image {
  /// One of the app's own symbols, from `Icons.xcassets`.
  init(_ icon: OpenDivingKit.Icon) {
    self.init(icon.rawValue)
  }

  /// One of the app's own symbols, already loaded. What the system draws by name — a menu, a
  /// view in the top bar — it finds only in its own set. A template, as a symbol by name is:
  /// loaded, it keeps the black it was drawn in, whatever the foreground.
  init(loaded icon: OpenDivingKit.Icon) {
    if let symbol = UIImage(named: icon.rawValue) {
      self.init(uiImage: symbol.withRenderingMode(.alwaysTemplate))
    } else {
      self.init(icon)
    }
  }
}

extension Label where Title == Text, Icon == Image {
  /// A menu item, whose symbol has to reach the menu already loaded.
  init(menuItem title: String, icon: OpenDivingKit.Icon) {
    self.init {
      Text(title)
    } icon: {
      Image(loaded: icon)
    }
  }

  init(_ title: String, icon: OpenDivingKit.Icon) {
    self.init {
      Text(title)
    } icon: {
      Image(icon)
    }
  }
}

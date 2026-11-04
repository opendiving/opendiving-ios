import OpenDivingKit
import SwiftUI

// `Icon` inside a `Label` extension is the label's own generic parameter, hence the module
// prefix.

extension Image {
  /// One of the app's own symbols, from `Icons.xcassets`.
  init(_ icon: OpenDivingKit.Icon) {
    self.init(icon.rawValue)
  }
}

extension Label where Title == Text, Icon == Image {
  /// A menu item. The system's menus draw a symbol by name only from its own set, so one of the
  /// app's has to reach them already loaded.
  init(menuItem title: String, icon: OpenDivingKit.Icon) {
    self.init {
      Text(title)
    } icon: {
      UIImage(named: icon.rawValue).map(Image.init(uiImage:)) ?? Image(icon)
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

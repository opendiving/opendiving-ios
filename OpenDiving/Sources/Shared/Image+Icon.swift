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
  init(_ title: String, icon: OpenDivingKit.Icon) {
    self.init {
      Text(title)
    } icon: {
      Image(icon)
    }
  }
}

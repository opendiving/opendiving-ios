import SwiftUI

extension Shape where Self == RoundedRectangle {
  /// The corners of a form's section, which each system draws its own and neither names:
  /// measured, 26 from iOS 26 and 10 before. A card takes them, so it reads as a form's section.
  static var formSection: RoundedRectangle {
    if #available(iOS 26, *) {
      RoundedRectangle(cornerRadius: 26)
    } else {
      RoundedRectangle(cornerRadius: 10)
    }
  }
}

import UIKit

extension UIApplication {
  /// Takes the keyboard away before a sheet opens over the form. UIKit hands the first responder
  /// back when the sheet closes, and the form then scrolls to that box, away from what was picked.
  static func endTyping() {
    shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}

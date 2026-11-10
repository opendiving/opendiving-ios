import OpenDivingKit
import SwiftUI

extension View {
  /// Reads the account when a settings screen appears, and again each time the app returns to
  /// the foreground while it shows.
  func followsAccount(_ session: Session) -> some View {
    task { await session.followAccountWhileShowing() }
  }
}

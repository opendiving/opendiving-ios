import SwiftUI

/// What the phone holds that the server does not have yet, above the Dives list. Nothing is
/// queued on the phone yet, so it draws nothing.
struct PendingSection: View {
  var body: some View {
    EmptyView()
  }
}

#Preview {
  PendingSection()
}

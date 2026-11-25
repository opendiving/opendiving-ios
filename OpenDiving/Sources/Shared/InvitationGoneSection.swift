import OpenDivingKit
import SwiftUI

/// That the connect link the diver came with is no longer active, on whichever sign-in screen
/// they are on when it is found gone: the email screen's read of it, or the code screen's, when
/// the request for the email found it reset.
struct InvitationGoneSection: View {
  var body: some View {
    Section {
      Label(SignInFlow.invitationGone, systemImage: "link")
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  Form {
    InvitationGoneSection()
  }
}

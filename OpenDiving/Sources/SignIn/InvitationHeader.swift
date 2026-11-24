import OpenDivingKit
import SwiftUI

/// What heads the sign-in screens while a connect link is held: its owner's picture, that they
/// invited the diver, and what a new account shares with them, as the web's landing page says
/// it.
struct InvitationHeader: View {
  let flow: SignInFlow
  let name: String
  let picture: ConnectedPicture?
  /// The line under the title, which the code screen, past the email, leaves out.
  var showsNote = true

  var body: some View {
    VStack(spacing: 12) {
      ConnectedPictureView(picture: picture, side: 72)
        .accessibilityHidden(true)
      Text(SignInFlow.invitationTitle(name))
        .font(.title3.bold())
        .accessibilityAddTraits(.isHeader)
      if showsNote {
        Text(flow.invitationNote(name))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
  }
}

#Preview {
  let session = Session.signedOutStub(transport: StubTransport(routes: [:]))
  InvitationHeader(flow: SignInFlow(session: session), name: "Robin Diver", picture: nil)
    .padding()
    .environment(session)
}

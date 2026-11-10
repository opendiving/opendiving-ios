import OpenDivingKit
import SwiftUI

/// A code redeemed into an account scheduled for deletion: when it is erased, and *Restore*,
/// which brings it back and signs in. Nothing is restored without the tap.
struct RestoreScreen: View {
  let flow: SignInFlow
  let email: String?
  let purgeAfter: String?

  var body: some View {
    ContentUnavailableView {
      Label("This account is scheduled for deletion", systemImage: "calendar.badge.clock")
    } description: {
      VStack(spacing: 12) {
        Text(SignInFlow.deletionMessage(email: email, purgeAfter: purgeAfter))
        if flow.canRestore {
          Text(SignInFlow.restoreNote(purgeAfter: purgeAfter))
        }
        if let error = flow.restoreError {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.danger)
        }
      }
    } actions: {
      if flow.canRestore {
        if flow.isRestoring {
          HStack {
            BubbleSpinner()
            Text("Restoring…")
          }
          .foregroundStyle(.secondary)
        } else {
          Button("Restore my account") { Task { await flow.restore() } }
            .brandProminentButton()
        }
      }
      Button("No thanks, leave it deleted") { flow.useDifferentEmail() }
        .buttonStyle(.bordered)
        .disabled(flow.isRestoring)
      if flow.canRestore {
        Text(SignInFlow.restoreOfferNote)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Sign In")
  }
}

#Preview {
  let session = Session.signedOutStub(transport: StubTransport(routes: [:]))
  NavigationStack {
    RestoreScreen(
      flow: SignInFlow(session: session), email: "sam@example.com", purgeAfter: "Nov 24, 2026")
  }
}

import OpenDivingKit
import SwiftUI

/// The saved servers, the active one first, to switch to, forget or open; *+* adds another.
/// Signed out it is a step of the sign-in; signed in, Settings pushes it.
struct ServerScreen: View {
  let flow: SignInFlow
  @State private var forgetting: ServerOrigin?
  @State private var showing: ServerOrigin?
  @State private var adding = false

  var body: some View {
    Form {
      if let notice = flow.notice {
        Section {
          Label(notice, systemImage: "info.circle")
        }
      }
      if let origin = flow.signingOut {
        Section {
          SigningOutRow(origin: origin) { flow.stopWaiting() }
        }
      }
      Section {
        ForEach(flow.savedServers) { server in
          HStack {
            Button {
              flow.switchTo(server.origin)
            } label: {
              SavedServerLabel(server: server)
            }
            // Two buttons in one row: a style other than the default gives each its own taps
            // rather than the row's, and plain keeps the address out of the tint.
            .buttonStyle(.plain)
            .disabled(flow.signingOut != nil)
            Button {
              showing = server.origin
            } label: {
              Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("About \(server.origin.description)")
          }
          .swipeActions {
            if server.canForget {
              Button("Forget", role: .destructive) { forgetting = server.origin }
            }
          }
        }
      } footer: {
        Text(KeptText.savedServersFooter)
      }
    }
    .navigationTitle("Servers")
    .toolbar {
      if flow.canCancelServerChange {
        // A back button of its own: signed out, this screen replaces the sign-in rather than
        // being pushed over it, so the stack has none to draw.
        ToolbarItem(placement: .navigation) {
          Button {
            flow.cancelServerChange()
          } label: {
            Image(systemName: "chevron.left")
          }
          .accessibilityLabel("Back")
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Button {
          adding = true
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Add server")
        .disabled(flow.signingOut != nil)
      }
    }
    .navigationDestination(item: $showing) { origin in
      SavedServerScreen(flow: flow, origin: origin)
    }
    .navigationDestination(isPresented: $adding) {
      AddServerScreen(flow: flow)
    }
    .forgetServerConfirmation(origin: $forgetting) { origin in
      Task { await flow.forget(origin) }
    }
  }
}

/// A saved server's address, whether the phone is signed in there, and a check on the active
/// one.
private struct SavedServerLabel: View {
  let server: SavedServer

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(server.origin.description)
          .foregroundStyle(.primary)
        Text(server.status)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if server.isActive {
        Image(systemName: "checkmark")
          .foregroundStyle(.tint)
          .accessibilityLabel("Current server")
      }
    }
    .contentShape(.rect)
  }
}

#Preview {
  let session = Session.signedOutStub(origin: nil, transport: StubTransport(routes: [:]))
  NavigationStack {
    ServerScreen(flow: SignInFlow(session: session))
  }
  .environment(session)
}

import OpenDivingKit
import SwiftUI

/// Signing in to the active server: the email field, what is reachable signed out — logging a
/// dive and what is waiting to sync for the account last signed in here, and the cached check-in
/// sheet — and the server card with another server.
struct EmailScreen: View {
  let flow: SignInFlow
  let origin: ServerOrigin
  let showSheet: () -> Void
  let showPending: () -> Void
  @Environment(OutboxModel.self) private var outbox
  @Environment(InboxModel.self) private var inbox
  @State private var logsDive = false
  @ScaledMetric(relativeTo: .body) private var spinnerSide: CGFloat = 24

  @FocusState private var focused: Bool

  var body: some View {
    Form {
      if let notice = flow.notice {
        Section {
          Label(notice, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.danger)
        }
      }
      Section {
        // Verbatim, because a literal address is parsed into a link and drawn in the link colour.
        TextField(
          "Email", text: Binding(get: { flow.email }, set: { flow.setEmail($0) }),
          prompt: Text(verbatim: "you@example.com")
        )
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.send)
        .onSubmit(send)
        .focused($focused)
      } header: {
        Text("Email").focusesOnTap($focused)
      } footer: {
        Text("We'll email you a six-digit sign-in code.")
      }
      if let error = flow.emailError {
        Section {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.danger)
        }
      }
      Section {
        Button(action: send) {
          // Held in place under the spinner, so the button keeps its size.
          Text("Sign in")
            .bold()
            .opacity(flow.isRequestingCode ? 0 : 1)
            .overlay {
              if flow.isRequestingCode {
                BubbleSpinner(side: spinnerSide).foregroundStyle(.white)
              }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(.brandCoral)
        .controlSize(.large)
        .accessibilityLabel("Sign in")
        .accessibilityValue(flow.isRequestingCode ? "Sending" : "")
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
      }
      Section {
        ForEach(flow.signedOutEntries) { entry in
          switch entry {
          case .logDive:
            SignedOutEntryRow(
              infoTitle: "Log a dive offline", info: entry.info(on: origin),
              infoLabel: "About logging a dive offline",
              action: { logsDive = true }
            ) {
              Label("Log a dive offline", icon: .dive)
            }
          case .waitingToSync:
            if let waiting {
              SignedOutEntryRow(
                infoTitle: "Waiting to sync", info: entry.info(on: origin),
                infoLabel: "About what is waiting to sync",
                action: showPending
              ) {
                Label(waiting, systemImage: "arrow.triangle.2.circlepath")
              }
            }
          case .checkInSheet:
            SignedOutEntryRow(
              infoTitle: "Your check-in sheet", info: entry.info(on: origin),
              infoLabel: "About your check-in sheet",
              action: showSheet
            ) {
              Label("Your check-in sheet", icon: .idCard)
            }
          }
        }
      }
      // A form row's automatic style draws an app symbol's label as its title alone.
      .labelStyle(.titleAndIcon)
      ServerCard(content: flow.session.card(for: origin)) {
        NavigationLink("Change server") {
          // A notice from an earlier visit is not this one's, though one set while here, by a
          // page pushed over the list, is. One the list showed is not the sign-in's, unless the
          // server it is about has changed under it.
          ServerScreen(flow: flow)
            .onFirstAppear { flow.dismissNotice() }
            .onDisappear { if flow.origin == origin { flow.dismissNotice() } }
        }
      }
    }
    .background(TapEndsTyping())
    .navigationTitle("Sign In")
    .navigationDestination(isPresented: $logsDive) { DiveFormView(mode: .create) }
    .task { await flow.session.loadServerInfo() }
    // Whenever the row is shown; the outbox refreshes nothing before the account loads.
    .task { await outbox.refreshDrafts() }
  }

  private var waiting: String? {
    PendingText.signedOutWaiting(
      drafts: outbox.drafts.count, items: outbox.items, unreadable: outbox.unreadable.count,
      files: inbox.files.count)
  }

  private func send() {
    if flow.isEmailEmpty {
      focused = true
    } else {
      Task { await flow.sendCode() }
    }
  }
}

#Preview {
  let session = Session.signedOutStub(
    origin: ServerOrigin("http://192.168.1.20:8000"), transport: StubTransport(routes: [:]))
  NavigationStack {
    EmailScreen(
      flow: SignInFlow(session: session), origin: session.state.origin!, showSheet: {},
      showPending: {})
  }
  .environment(session)
  .environment(OutboxModel(session: session))
  .environment(InboxModel(session: session))
}

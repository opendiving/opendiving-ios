import OpenDivingKit
import SwiftUI

/// What the window shows — the server and sign-in screens, or the sites map signed in, under the
/// launch splash until the first of them has loaded — and where the one session, the sign-in
/// flow Settings reaches back into, the inbox, the outbox, the dive-computer engine and its
/// screen's model, the presenter a tapped download notification and a link open in, and the
/// appearance are injected; and the offer to add a passkey after a sign-in, once nothing else is in
/// front. A link from outside the app is handed to the presenter, which opens
/// its screen or gives it back: for the browser, for the sign-in screens to redeem, or to hold
/// while the diver signs in, its screen opening once they have. The session,
/// the account's load, the inbox and the engine are the app delegate's, made before any view.
struct RootView: View {
  @State private var session: Session
  @State private var signIn: SignInFlow
  @State private var account: AccountLoader
  @State private var inbox: InboxModel
  @State private var outbox: OutboxModel
  @State private var engine: DiveComputerEngine
  @State private var downloads: DiveComputerDownloads
  @State private var presenter: ScreenPresenter
  @State private var splash = LaunchSplash()
  @State private var appearance = AppearanceModel(defaults: .standard)
  @State private var passkeyOffer: PasskeyOfferModel
  @Environment(\.openURL) private var openURL

  init(
    session: Session, account: AccountLoader, inbox: InboxModel, engine: DiveComputerEngine,
    presenter: ScreenPresenter = ScreenPresenter()
  ) {
    _session = State(initialValue: session)
    _signIn = State(initialValue: SignInFlow(session: session))
    _account = State(initialValue: account)
    _inbox = State(initialValue: inbox)
    _engine = State(initialValue: engine)
    _presenter = State(initialValue: presenter)
    _downloads = State(initialValue: DiveComputerDownloads(engine: engine))
    _passkeyOffer = State(initialValue: PasskeyOfferModel(session: session))
    // The quiet load: a reconnect that loads the account raises no alert of its own.
    _outbox = State(
      initialValue: OutboxModel(session: session, loadAccount: { await account.loadQuietly() }))
  }

  var body: some View {
    Group {
      switch session.state {
      // One branch for both, so the sign-in screens keep their place when a server is chosen.
      case .noServer, .signingIn:
        SignInView()
      case .signedIn(let origin):
        // Switching between two signed-in servers starts the app over, rather than
        // showing the last server's lists and screens under the new one.
        SitesView()
          .id(origin)
      }
    }
    // Never over a screen a link or a notification opened: it follows once that is closed.
    .sheet(
      isPresented: Binding(
        get: { passkeyOffer.isOffered && presenter.opened == nil },
        set: { if !$0 && presenter.opened == nil { passkeyOffer.close() } })
    ) {
      PasskeyOfferSheet(model: passkeyOffer)
        .environment(session)
    }
    .overlay {
      if splash.isShowing {
        LaunchSplashView()
          .transition(.opacity)
      }
    }
    .animation(.easeOut(duration: 0.3), value: splash.isShowing)
    .screenPresenterHost(presenter, session: session)
    .environment(session)
    .environment(signIn)
    .environment(downloads)
    .environment(engine)
    .appearanceHost(appearance)
    .inboxHost(inbox, session: session) { receive($0) }
    .outboxHost(outbox, session: session)
    .task { await account.launch() }
    .task {
      if let link = presenter.takeLaunchLink() { receive(link) }
    }
    .task { await session.followRouteChanges() }
    .task { await splash.run(session.requests) }
    .onChange(of: session.state) { old, new in
      if let held = signIn.takeHeldScreen(new) { presenter.open(held) }
      passkeyOffer.close()
      downloads.sessionChanged()
      engine.sessionChanged()
      Task { await account.sessionChanged(from: old, to: new) }
    }
    .onChange(of: session.accountLoaded) {
      engine.accountLoaded()
      if session.accountLoaded { Task { await passkeyOffer.check() } }
    }
    .alert(
      "Your account could not be loaded",
      isPresented: Binding(
        get: { account.failure != nil },
        set: { if !$0 { account.dismissFailure() } })
    ) {
      Button("Try again") { Task { await account.retry() } }
      Button("OK", role: .cancel) {}
    } message: {
      Text(account.failure ?? "")
    }
  }
}

extension RootView {
  /// A link from outside: its screen, a sign-in, a link held for one, or else the browser, at
  /// once.
  private func receive(_ url: URL) {
    switch presenter.receive(url, state: session.state) {
    case .browser(let url): openURL(url)
    case .signIn(let token): Task { await signIn.redeemLink(token) }
    case .hold(let screen): Task { await signIn.hold(screen) }
    // The presenter opened it; and only a given link is answered.
    case .open, .answer, nil: break
    }
  }
}

extension RootView {
  /// The root over a session alone, with models of its own: a preview's, or a test's.
  init(session: Session) {
    self.init(
      session: session, account: AccountLoader(session: session),
      inbox: InboxModel(session: session),
      engine: DiveComputerEngine(
        session: session, makeLink: { LibDCDiveComputerLink(manager: nil, defaults: .standard) },
        generator: DiveComputerView.generator))
  }
}

#Preview("Signed out") {
  RootView(session: .signedOutStub(origin: nil, transport: StubTransport(routes: [:])))
}

#Preview("Signed in") {
  RootView(session: .stub(transport: StubTransport(routes: [:])))
}

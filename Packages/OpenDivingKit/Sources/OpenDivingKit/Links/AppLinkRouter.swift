import Foundation

/// What the app does with an address, by where it came from and the session's state. The app acts
/// on a link only for the server it is on: the session has one active server, and switching it
/// from a link would start the app over under whatever the diver had open. A connect link on the
/// flagship, while the app is on another server, asks the diver whether to switch. What it does
/// not act on goes to the browser when it came from outside, and is answered when it was given.
/// Signed out on the link's server, a sign-in link is redeemed, and a record or a connect link
/// from outside is held until the diver has signed in.
public enum AppLinkRouter {
  public enum Source: Hashable, Sendable {
    /// Handed to the app by iOS, or by the simulator's launch argument.
    case outside
    /// Scanned or pasted in the app.
    case given
  }

  public enum Action: Hashable, Sendable {
    /// The link's screen opens.
    case open(AppLink.Screen)
    /// The address opens in the browser.
    case browser(URL)
    /// The sign-in screens redeem the link's token.
    case signIn(token: String)
    /// The screen opens once the diver has signed in on the link's server; from outside only.
    case hold(AppLink.Screen)
    /// A given link the app does not act on, answered where it was given.
    case answer(GivenLinkAnswer)
    /// A connect link on the flagship from outside, while the app is on another server: the
    /// diver is asked whether to switch to the flagship to open it, or to open it in the browser.
    case offerFlagship(FlagshipOffer)
  }

  public static func action(for url: URL, from source: Source, state: Session.State) -> Action {
    func notActedOn(_ answer: GivenLinkAnswer) -> Action {
      source == .outside ? .browser(url) : .answer(answer)
    }
    guard let link = AppLink(url) else { return notActedOn(.notALink) }
    guard link.origin == state.origin else {
      if link.origin.isFlagship, case .connect(let token) = link.target, let current = state.origin
      {
        let signedIn = if case .signedIn = state { true } else { false }
        let offer = FlagshipOffer(token: token, current: current, isSignedIn: signedIn, url: url)
        return source == .outside ? .offerFlagship(offer) : .answer(.flagship(offer))
      }
      return notActedOn(.otherServer(link.origin, current: state.origin, url: url))
    }
    let signedIn = if case .signedIn = state { true } else { false }
    func opened(_ screen: AppLink.Screen) -> Action {
      if signedIn { return .open(screen) }
      return source == .outside ? .hold(screen) : .answer(.signInFirst)
    }
    switch link.target {
    case .record(let record):
      return opened(.record(record))
    case .connect(let token):
      return opened(.connect(token: token))
    case .signIn(let token):
      return signedIn ? notActedOn(.signedInAlready) : .signIn(token: token)
    }
  }
}

/// What the app says of a scanned or pasted address it does not act on.
public enum GivenLinkAnswer: Hashable, Sendable {
  /// A link of a page the app opens, on a server the app is not on, which the browser is offered
  /// for.
  case otherServer(ServerOrigin, current: ServerOrigin?, url: URL)
  /// A connect link on the flagship while the app is on another server, which the switch to the
  /// flagship is offered for, and the browser.
  case flagship(FlagshipOffer)
  case notALink
  case signedInAlready
  case signInFirst

  public var sentence: String {
    switch self {
    case .otherServer(let origin, let current, _):
      if let current {
        "This link is for \(origin), and the app is on \(current)."
      } else {
        "This link is for \(origin), and the app is on no server."
      }
    case .flagship(let offer): offer.sentence
    case .notALink: "This is not a link the app opens."
    case .signedInAlready: "This is a sign-in link, and the app is signed in already."
    case .signInFirst: "Sign in to open this link."
    }
  }

  /// The address to offer in the browser, for a link on another server alone.
  public var browser: URL? {
    switch self {
    case .otherServer(_, _, let url): url
    case .flagship(let offer): offer.url
    case .notALink, .signedInAlready, .signInFirst: nil
    }
  }

  public static let openInBrowser = "Open in Safari"
}

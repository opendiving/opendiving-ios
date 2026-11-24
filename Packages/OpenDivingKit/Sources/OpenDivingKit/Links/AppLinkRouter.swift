import Foundation

/// What the app does with an address, by where it came from and the session's state. The app acts
/// on a link only for the server it is on: the session has one active server, and switching it
/// from a link would start the app over under whatever the diver had open. What it does not act
/// on goes to the browser when it came from outside, and is answered when it was given.
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
    /// A given link the app does not act on, answered where it was given.
    case answer(GivenLinkAnswer)
  }

  public static func action(for url: URL, from source: Source, state: Session.State) -> Action {
    func notActedOn(_ answer: GivenLinkAnswer) -> Action {
      source == .outside ? .browser(url) : .answer(answer)
    }
    guard let link = AppLink(url) else { return notActedOn(.notALink) }
    guard link.origin == state.origin else {
      return notActedOn(.otherServer(link.origin, current: state.origin, url: url))
    }
    let signedIn = if case .signedIn = state { true } else { false }
    switch link.target {
    case .record(let record):
      return signedIn ? .open(.record(record)) : notActedOn(.signInFirst)
    case .connect(let token):
      return signedIn ? .open(.connect(token: token)) : notActedOn(.signInFirst)
    case .signIn:
      return notActedOn(signedIn ? .signedInAlready : .signInWithTheCode)
    }
  }
}

/// What the app says of a scanned or pasted address it does not act on.
public enum GivenLinkAnswer: Hashable, Sendable {
  /// A link of a page the app opens, on a server the app is not on: the only answer that offers
  /// the browser.
  case otherServer(ServerOrigin, current: ServerOrigin?, url: URL)
  case notALink
  case signedInAlready
  case signInFirst
  case signInWithTheCode

  public var sentence: String {
    switch self {
    case .otherServer(let origin, let current, _):
      if let current {
        "This link is for \(origin), and the app is on \(current)."
      } else {
        "This link is for \(origin), and the app is on no server."
      }
    case .notALink: "This is not a link the app opens."
    case .signedInAlready: "This is a sign-in link, and the app is signed in already."
    case .signInFirst: "Sign in to open this link."
    case .signInWithTheCode: "Sign in with the code the same email gives."
    }
  }

  /// The address to offer in the browser, for a link on another server alone.
  public var browser: URL? {
    if case .otherServer(_, _, let url) = self { url } else { nil }
  }

  public static let openInBrowser = "Open in Safari"
}

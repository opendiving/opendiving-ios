import Foundation
import Observation

/// *Sign in faster next time*: the offer to add a passkey, made once to an account on this
/// phone, after a sign-in the diver completed in the app without one, where a passkey is
/// offered and the account has none. *Not now*, or a passkey added from it, is the account's
/// answer on this phone; an offer closed any other way was not answered.
@MainActor
@Observable
public final class PasskeyOfferModel {
  public private(set) var isOffered = false
  public private(set) var isAdding = false
  /// What the last *Add a passkey* that added nothing says, as Settings' control would.
  public private(set) var message: String?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var offeredTo: (origin: ServerOrigin, account: UUID)?

  public init(session: Session) {
    self.session = session
  }

  public static let title = "Sign in faster next time"
  public static let sentence =
    "Add a passkey: your fingerprint, face or device PIN, instead of waiting for an email. Your"
    + " email link keeps working either way."
  public static let addButton = "Add a passkey"
  public static let notNowButton = "Not now"

  /// Makes the offer, once the account has loaded after a sign-in, when everything says to: a
  /// passkey list that cannot be read, or a server without one, makes none.
  public func check() async {
    guard case .signedIn(let origin) = session.state, session.accountLoaded,
      session.signedInWith == .email, session.offersPasskeys, let account = session.user?.uuid,
      !session.store.answeredPasskeyOffer(for: origin, account: account)
    else { return }
    guard let passkeys = try? await session.routedClient().passkeys(), passkeys.isEmpty,
      session.state == .signedIn(origin), session.user?.uuid == account
    else { return }
    offeredTo = (origin, account)
    message = nil
    isOffered = true
  }

  public func notNow() {
    answer()
  }

  /// Runs the ceremony Settings' *Add passkey* runs: an added passkey answers the offer, and
  /// anything else leaves it open with what that control would say.
  public func add() async {
    guard isOffered, !isAdding else { return }
    isAdding = true
    message = nil
    defer { isAdding = false }
    switch await PasskeyAdding.add(session) {
    case .added: answer()
    case .dismissed: break
    case .alreadyOnThisPhone: message = PasskeyAdding.alreadyOnThisPhone
    case .failed(let sentence): message = sentence
    }
  }

  /// Closes the offer unanswered: swiped away, or the session it was made in ended.
  public func close() {
    isOffered = false
    offeredTo = nil
    message = nil
  }

  private func answer() {
    if let offeredTo {
      try? session.store.rememberPasskeyOfferAnswered(
        for: offeredTo.origin, account: offeredTo.account)
    }
    close()
  }
}

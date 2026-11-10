extension SignInFlow {
  /// The unfinished-account screen's sentence.
  public static func onboardingMessage(email: String?, origin: ServerOrigin?) -> String {
    let account = email.map { "The account for \($0)" } ?? "This account"
    return account + " isn't finished yet. Sign-up is completed on the web, at "
      + (origin?.description ?? "this server") + "; then sign in here."
  }

  /// The deletion-pending screen's sentence. `purgeAfter` is the day, ready to print.
  public static func deletionMessage(email: String?, purgeAfter: String?) -> String {
    let erased =
      purgeAfter.map { " are erased for good on \($0)." }
      ?? " are erased for good once this server's grace period runs out."
    return (email ?? "This account") + " was deleted, and nothing has been erased yet. "
      + Self.everythingErased + erased
  }

  /// Under the deletion-pending sentence, while *Restore* is offered.
  public static func restoreNote(purgeAfter: String?) -> String {
    "Restoring brings all of it back and signs you in."
      + (purgeAfter == nil ? "" : " Leave it, and the date above decides.")
  }

  /// Under *Restore*: the offer lives only as long as the screen.
  public static let restoreOfferNote =
    "This offer belongs to the sign-in you just completed. Leave this screen and you sign in"
    + " again to get back to it."

  public static let goodbyeTitle = "Your account has been deleted"

  /// The goodbye's sentence: the day the deletion's answer named, ready to print.
  public static func goodbyeMessage(purgeAfter: String) -> String {
    "You're signed out everywhere, and nothing has been erased yet. " + Self.everythingErased
      + " will be permanently erased on \(purgeAfter)."
  }

  /// The way back, in the web's words.
  public static let goodbyeRestore =
    "Deleted by mistake? Sign in again before that date and you'll be offered your account"
    + " back. Afterwards, nothing can be restored."

  /// What the phone still keeps for `origin` after the deletion, and what removes it. The
  /// flagship offers no *Forget*, so its sentence stops at what is kept.
  public static func goodbyeKept(_ origin: ServerOrigin) -> String {
    KeptText.held(origin) + (origin.isFlagship ? "" : " Forget this server removes all of it.")
  }

  /// Everything a deletion erases, in the web's order.
  private static let everythingErased =
    "Your dives, dive drafts, dive sites, trips, courses, certifications, gear, contacts, people"
    + " and tags"
}

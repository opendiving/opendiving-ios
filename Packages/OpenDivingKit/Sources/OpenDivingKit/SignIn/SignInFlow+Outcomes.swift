extension SignInFlow {
  /// The unfinished-account screen's sentence.
  public static func onboardingMessage(email: String?, origin: ServerOrigin?) -> String {
    let account = email.map { "The account for \($0)" } ?? "This account"
    return account + " isn't finished yet. Sign-up is completed on the web, at "
      + (origin?.description ?? "this server") + "; then sign in here."
  }

  /// The deletion-pending screen's sentence. `purgeAfter` is the day, ready to print.
  public static func deletionMessage(email: String?, purgeAfter: String?, origin: ServerOrigin?)
    -> String
  {
    let account = email.map { "The account for \($0)" } ?? "This account"
    let when = purgeAfter.map { " after \($0)" } ?? ""
    return account + " is scheduled to be deleted" + when + ". Until then it can be restored"
      + " on the web, at " + (origin?.description ?? "this server") + "."
  }
}

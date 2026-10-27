import Foundation

/// Every sentence that says what the phone keeps for a server, in one place, so that a new
/// thing kept is named by all of them at once: the sign-in, the account, the check-in sheet,
/// the drafts, the writes waiting to sync, the files waiting to be read, the dive computers
/// downloaded from and the copies of the logbook kept for offline.
public enum KeptText {
  private static let afterSignOut =
    "Your check-in sheet, your drafts, the dives waiting to sync, the files waiting to be read,"
    + " the dive computers you have downloaded from and the copies of your logbook kept for"
    + " offline stay on this phone after you sign out"

  /// Under the signed-out screen's entries.
  public static let signedOutFooter = afterSignOut + ", until you forget the server."

  /// Under Settings' sign-out.
  public static let settingsFooter =
    "Signing out needs the server. " + afterSignOut
    + " or change server, until you forget the server."

  /// Under a *Forget* offered for a server that is not active.
  public static func held(_ origin: ServerOrigin) -> String {
    "This phone holds a sign-in, an account, a check-in sheet, drafts, dives waiting to sync,"
      + " files waiting to be read, dive computers downloaded from or copies of the logbook for"
      + " \(origin)."
  }

  /// The one warning before `forget` discards what has not reached the server: what it
  /// removes, and by count what it would lose, across every account the phone has signed in
  /// to there.
  public static func forgetMessage(_ summary: OutboxSummary) -> String {
    let removes =
      "Removes the server's sign-in, your account details, the saved check-in sheet, your"
      + " drafts, "
    let rest =
      "the files waiting to be read, the dive computers you have downloaded from and the copies"
      + " of your logbook kept for offline"
    let after =
      " It signs out on the server first when it can; it removes them even when the server"
      + " cannot be reached."
    guard !summary.isEmpty else {
      return removes + "the dives waiting to sync, " + rest + " from this phone." + after
    }
    var parts: [String] = []
    func count(_ n: Int, _ one: String, _ many: String) {
      if n > 0 { parts.append(n == 1 ? "1 \(one)" : "\(n) \(many)") }
    }
    count(summary.dives, "dive", "dives")
    count(summary.others, "other change", "other changes")
    count(summary.editDrafts, "unfinished dive edit", "unfinished dive edits")
    count(
      summary.unreadable, "item saved by another version of the app",
      "items saved by another version of the app")
    let total = summary.dives + summary.others + summary.editDrafts + summary.unreadable
    let have = total == 1 ? "has" : "have"
    return removes + rest + " from this phone, and " + PendingText.list(parts)
      + " that \(have) not been saved to the server." + after
  }

  /// What a *Forget* that worked says on the screen it lands on.
  public static func forgotten(_ origin: ServerOrigin) -> String {
    "Removed everything this phone kept for \(origin): its sign-in, account, check-in sheet,"
      + " drafts, dives waiting to sync, files waiting to be read, dive computers downloaded from"
      + " and copies of the logbook kept for offline."
  }
}

/// What the lists and the dive page say when what they show is the phone's copy.
public enum OfflineText {
  /// Above rows, or a dive, shown from the phone's copy: *Last updated Oct 25, 2026, 14:02*.
  public static func lastUpdated(_ at: Date, in timeZone: TimeZone = .current) -> String {
    "Last updated " + DateText.dateTime(at, in: timeZone)
  }

  /// On a dive whose edit is queued, which the page already shows.
  public static let pendingEdit = "Edited on this phone, waiting to sync."
  /// A dive the phone has never opened, which only the server can show.
  public static let diveNotShown =
    "This dive has not been opened on this phone, so it shows once the server can be reached."
  /// The profile card of a dive shown from the phone's copy: profiles are not kept.
  public static let profileNeedsServer =
    "Profiles are not kept on this phone, so this one shows once the server can be reached."
}

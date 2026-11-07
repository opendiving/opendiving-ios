import Foundation

/// Every sentence that says what the phone keeps for a server, in one place, so that a new
/// thing kept is named by all of them at once: the sign-in, the account, the check-in sheet,
/// the drafts, the writes waiting to sync, the files waiting to be read, the dive computer
/// download history and the copies of the logbook kept for offline. The paired dive computers
/// are the phone's, kept for no server, so none of these names them.
public enum KeptText {
  private static let afterSignOut =
    "Your check-in sheet, your drafts, the dives waiting to sync, the files waiting to be read,"
    + " your dive computer download history and the copies of your logbook kept for"
    + " offline stay on this phone after you sign out"

  /// Behind the signed-out screen's info button, for `origin`: only a server that can be
  /// forgotten mentions it.
  public static func signedOutKept(_ origin: ServerOrigin) -> String {
    afterSignOut + (origin.isFlagship ? "." : ", until you forget the server.")
  }

  /// Under the saved servers.
  public static let savedServersFooter =
    "Changing server keeps you signed in to the one you leave, and everything this phone keeps"
    + " for it."

  /// Under a *Forget* offered for a server that is not active.
  public static func held(_ origin: ServerOrigin) -> String {
    "This phone holds a sign-in, an account, a check-in sheet, drafts, dives waiting to sync,"
      + " files waiting to be read, dive computer download history or copies of the logbook for"
      + " \(origin)."
  }

  /// The one line the *Forget* confirmation carries, and only when it would lose something:
  /// what has not reached the server, by count, across every account the phone has signed in
  /// to there. Nil when nothing would be lost.
  public static func forgetMessage(_ summary: OutboxSummary) -> String? {
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
    guard !parts.isEmpty else { return nil }
    let total = summary.dives + summary.others + summary.editDrafts + summary.unreadable
    let have = total == 1 ? "has" : "have"
    return PendingText.list(parts) + " \(have) not been saved to the server and will be lost."
  }
}

/// What the lists and the dive page say when what they show is the phone's copy.
public enum OfflineText {
  /// Above rows, or a dive, shown from the phone's copy: *Last updated Oct 25, 2026, 14:02*.
  public static func lastUpdated(_ at: Date, in timeZone: TimeZone = .current) -> String {
    "Last updated " + DateText.dateTime(at, in: timeZone)
  }

  /// On a record whose edit is queued. A dive's page already shows the edit; a trip's or a
  /// site's shows it once it lands.
  public static let pendingEdit = "Edited on this phone, waiting to sync."
  /// A dive the phone has never opened, which only the server can show.
  public static let diveNotShown =
    "This dive has not been opened on this phone, so it shows once the server can be reached."
  /// The profile card of a dive shown from the phone's copy: profiles are not kept.
  public static let profileNeedsServer =
    "Profiles are not kept on this phone, so this one shows once the server can be reached."
}

import Foundation

/// What the phone keeps for a server, as a whole: ``held(_:)`` names every kept thing, so a new
/// one goes there: the sign-in, the account, the check-in sheet, the drafts, the writes waiting
/// to sync, the card images waiting to be sent, the files waiting to be read, the dive computer
/// download history, and the copies kept for offline of the logbook and of the gear, training,
/// people and marine life it names. The paired dive computers are the phone's, kept for no
/// server, so it does not name them. ``SignedOutEntry/info(on:)`` says what stays of one entry
/// alone.
public enum KeptText {
  /// Under the saved servers.
  public static let savedServersFooter =
    "Changing server keeps you signed in to the one you leave, and everything this phone keeps"
    + " for it."

  /// Under a *Forget* offered for a server that is not active.
  public static func held(_ origin: ServerOrigin) -> String {
    "This phone holds a sign-in, an account, a check-in sheet, drafts, dives and other changes"
      + " waiting to sync, card images waiting to be sent, files waiting to be read, dive"
      + " computer download history or copies of the logbook, gear, training, people and marine"
      + " life for \(origin)."
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

/// What the lists and the record pages say when what they show is the phone's copy.
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
  /// A dive site the phone has never opened, which only the server can show.
  public static let siteNotShown =
    "This dive site has not been opened on this phone, so it shows once the server can be"
    + " reached."
  /// A trip the phone has never opened, which only the server can show.
  public static let tripNotShown =
    "This trip has not been opened on this phone, so it shows once the server can be reached."
  /// A gear item the phone has never opened, which only the server can show.
  public static let gearItemNotShown =
    "This gear has not been opened on this phone, so it shows once the server can be reached."
  /// A course the phone has never opened, which only the server can show.
  public static let courseNotShown =
    "This course has not been opened on this phone, so it shows once the server can be reached."
  /// A certification the phone has never opened, which only the server can show.
  public static let certificationNotShown =
    "This certification has not been opened on this phone, so it shows once the server can be"
    + " reached."
  /// A person the phone has never opened, which only the server can show.
  public static let personNotShown =
    "This person has not been opened on this phone, so they show once the server can be"
    + " reached."
  /// A species the phone has never opened, which only the server can show.
  public static let speciesNotShown =
    "This species has not been opened on this phone, so it shows once the server can be"
    + " reached."
  /// A record's dives the phone has not listed — a site's, a trip's, a gear item's, a
  /// course's, a person's or a species' — which only the server can show.
  public static let divesNotShown =
    "These dives have not been listed on this phone, so they show once the server can be"
    + " reached."
  /// More's *Gear* never listed, which only the server can show.
  public static let gearNotShown =
    "Your gear has not been listed on this phone, so it shows once the server can be reached."
  /// The gear sets under *Gear* never listed.
  public static let gearSetsNotShown =
    "Your gear sets have not been listed on this phone, so they show once the server can be"
    + " reached."
  /// A gear item's service never shown: its rules and its history.
  public static let gearServiceNotShown =
    "This gear's service has not been shown on this phone, so it shows once the server can be"
    + " reached."
  /// More's *Certifications*, or a course's, never listed.
  public static let certificationsNotShown =
    "These certifications have not been listed on this phone, so they show once the server can"
    + " be reached."
  /// More's *Courses* never listed.
  public static let coursesNotShown =
    "Your courses have not been listed on this phone, so they show once the server can be"
    + " reached."
  /// More's *People* never listed.
  public static let peopleNotShown =
    "Your people have not been listed on this phone, so they show once the server can be"
    + " reached."
  /// More's *Contacts* never listed.
  public static let contactsNotShown =
    "Your contacts have not been listed on this phone, so they show once the server can be"
    + " reached."
  /// More's *Marine Life* never listed.
  public static let lifeListNotShown =
    "Your marine life has not been listed on this phone, so it shows once the server can be"
    + " reached."
  /// More's *Your dive sites* never listed.
  public static let yourDiveSitesNotShown =
    "Your dive sites have not been listed on this phone, so they show once the server can be"
    + " reached."
  /// The Sites map's weather bar, where the weather could not be asked for.
  public static let noConnection = "No connection"
  /// The profile card of a dive shown from the phone's copy: profiles are not kept.
  public static let profileNeedsServer =
    "Profiles are not kept on this phone, so this one shows once the server can be reached."
}

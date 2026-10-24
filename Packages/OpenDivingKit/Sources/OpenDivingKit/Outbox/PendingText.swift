import Foundation

/// The pending section's and the pending screen's words: what the phone holds that the server
/// does not have yet, said in plain words. The server's own sentences are shown as it wrote
/// them, never through here.
public enum PendingText {
  public static let title = "Waiting to sync"
  public static let syncNow = "Sync now"
  public static let signInToSync = "Sign in to sync"
  public static let signInToSyncDetail =
    "Everything here stays on this phone and is sent once you are signed in."
  public static let unreadableDiscard =
    "This version of the app cannot read it, so it cannot be sent. Discarding removes it from this"
    + " phone."

  /// *2 drafts*.
  public static func drafts(_ count: Int) -> String {
    count == 1 ? "1 draft" : "\(count) drafts"
  }

  /// *A dive, a site and a buddy waiting to sync*: the writes that have not failed, a draft's
  /// own create and changes left to the drafts row. Nil when there are none.
  public static func waiting(_ items: [OutboxItem]) -> String? {
    var counts: [Noun: Int] = [:]
    var order: [Noun] = []
    for item in items where !item.isFailed {
      guard let noun = Noun(item.operation) else { continue }
      if counts[noun] == nil { order.append(noun) }
      counts[noun, default: 0] += 1
    }
    guard !order.isEmpty else { return nil }
    let phrases = order.sorted().map { noun in
      let count = counts[noun] ?? 0
      return count == 1 ? "a \(noun.singular)" : "\(count) \(noun.plural)"
    }
    return capitalized(list(phrases)) + " waiting to sync"
  }

  /// *1 could not be saved*.
  public static func failed(_ count: Int) -> String {
    "\(count) could not be saved"
  }

  /// One item this build cannot read is *Saved by another version of the app*.
  public static func unreadable(_ count: Int) -> String {
    count == 1 ? OutboxText.unreadableItem : "\(count) saved by another version of the app"
  }

  /// *2 files waiting*, to be read for import.
  public static func filesWaiting(_ count: Int) -> String {
    count == 1 ? "1 file waiting" : "\(count) files waiting"
  }

  /// What a queued write is, by the record it makes or changes. `dive` names a dive the phone
  /// has shown, for an edit of one.
  public static func title(
    of item: OutboxItem, dive: (UUID) -> DiveReadWithMixtures? = { _ in nil }
  ) -> String {
    switch item.operation {
    case .createDive(let body), .logDive(_, let body):
      return "Dive \(body.diveNumber), \(DateText.diveDateTime(body.startTime))"
    case .updateDive(let ref, _):
      guard case .server(let uuid) = ref, let shown = dive(uuid) else {
        return "Changes to a dive"
      }
      return
        "Changes to dive \(shown.diveNumber), \(DateText.diveDateTime(shown.startTime))"
    case .createDiveSite(let body): return named("Dive site", body.name)
    case .createPerson(let body): return named("Buddy", body.name)
    case .createTrip(let body): return named("Trip", body.name)
    case .createCourse(let body): return named("Course", body.name)
    case .createContact(let body): return named("Contact", body.name)
    case .createGearItem(let body): return named("Gear", body.name)
    case .createGearSet(let body): return named("Gear set", body.name)
    case .updateGearSet(_, let body):
      return body.name.map { named("Changes to gear set", $0) } ?? "Changes to a gear set"
    case .createDiveDraft(let write), .updateDiveDraft(_, let write):
      return "Draft: " + draftTitle(write)
    case .deleteDiveDraft:
      return "A discarded draft"
    }
  }

  /// *Queued Oct 25, 2026, 14:02*.
  public static func queued(_ at: Date, in timeZone: TimeZone = .current) -> String {
    "Queued " + DateText.dateTime(at, in: timeZone)
  }

  /// What a write moved from another account's stores left out: *Logged before your account
  /// was known; the dive site it named was left out*. Nil when it left nothing out.
  public static func dropped(_ item: OutboxItem) -> String? {
    guard !item.dropped.isEmpty else { return nil }
    let verb = item.operation.kind == .dive ? "Logged" : "Saved"
    let named = list(item.dropped.map { "the " + Noun.record($0) })
    let was = item.dropped.count == 1 ? "was" : "were"
    return "\(verb) before your account was known; \(named) it named \(was) left out"
  }

  /// An item waiting behind a failed one.
  public static func heldBehind(_ failed: String) -> String {
    "Waiting for \(failed), which could not be saved"
  }

  /// What *Discard* changes, for its confirmation: the item never reaches the server, what
  /// named the record it would have made goes on without it, what wrote to that record goes
  /// with it, and a log of a discarded draft is sent as a dive of its own.
  public static func discardMessage(released: [String], withdrawn: [String], logged: [String])
    -> String
  {
    var message = "It is removed from this phone and never reaches the server."
    if !released.isEmpty {
      message += " \(list(released)) \(released.count == 1 ? "goes" : "go") on without it."
    }
    if !withdrawn.isEmpty {
      message += " \(list(withdrawn)) \(withdrawn.count == 1 ? "is" : "are") discarded with it."
    }
    if !logged.isEmpty {
      message += " \(list(logged)) \(logged.count == 1 ? "is" : "are") logged as a new dive."
    }
    return message
  }

  /// A draft by its start, or *Untitled draft*, as the web lists it.
  public static func draftTitle(_ write: DiveDraftWrite) -> String {
    write.values.startTime.map(DateText.diveDateTime) ?? "Untitled draft"
  }

  /// *Changed Oct 25, 2026, 14:02*, and whether the change is still to reach the server.
  public static func draftChanged(_ entry: DiveDraftEntry, in timeZone: TimeZone = .current)
    -> String
  {
    let changed = "Changed " + DateText.dateTime(entry.changedAt, in: timeZone)
    return entry.hasPendingChange ? changed + ", waiting to sync" : changed
  }

  // MARK: - Words

  /// What a queued write is about, in the pending section's words, in the order it lists them.
  private enum Noun: Int, Comparable {
    case dive, site, buddy, trip, course, contact, gear, gearSet, discardedDraft

    init?(_ operation: OutboxOperation) {
      switch operation {
      case .createDiveDraft, .updateDiveDraft: return nil
      case .deleteDiveDraft: self = .discardedDraft
      default:
        switch operation.kind {
        case .dive: self = .dive
        case .diveSite: self = .site
        case .person: self = .buddy
        case .trip: self = .trip
        case .course: self = .course
        case .contact: self = .contact
        case .gearItem: self = .gear
        case .gearSet: self = .gearSet
        case .diveDraft: self = .discardedDraft
        }
      }
    }

    var singular: String {
      switch self {
      case .dive: "dive"
      case .site: "site"
      case .buddy: "buddy"
      case .trip: "trip"
      case .course: "course"
      case .contact: "contact"
      case .gear: "piece of gear"
      case .gearSet: "gear set"
      case .discardedDraft: "discarded draft"
      }
    }

    var plural: String {
      switch self {
      case .buddy: "buddies"
      case .gear: "pieces of gear"
      default: singular + "s"
      }
    }

    static func < (a: Noun, b: Noun) -> Bool { a.rawValue < b.rawValue }

    static func record(_ kind: OutboxRecordKind) -> String {
      switch kind {
      case .dive: "dive"
      case .diveSite: "dive site"
      case .person: "buddy"
      case .trip: "trip"
      case .course: "course"
      case .contact: "contact"
      case .gearItem: "gear"
      case .gearSet: "gear set"
      case .diveDraft: "draft"
      }
    }
  }

  private static func named(_ kind: String, _ name: String) -> String {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? kind : "\(kind): \(name)"
  }

  /// `a`, `a and b`, `a, b and c`.
  static func list(_ parts: [String]) -> String {
    switch parts.count {
    case 0: ""
    case 1: parts[0]
    default: parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
    }
  }

  private static func capitalized(_ text: String) -> String {
    text.prefix(1).uppercased() + text.dropFirst()
  }
}

/// The rows above the Dives list, each omitted when it would count nothing: the drafts, the
/// writes waiting, the failures, each done-but-unreadable notice until dismissed, the items
/// this build cannot read, and the files waiting to be read.
public struct PendingSummary: Hashable, Sendable {
  public enum Row: Hashable, Sendable, Identifiable {
    case drafts(String)
    case waiting(String)
    case failed(String)
    case notice(id: UUID, String)
    case unreadable(String)
    case files(String)

    public var id: String {
      switch self {
      case .drafts: "drafts"
      case .waiting: "waiting"
      case .failed: "failed"
      case .notice(let id, _): "notice-\(id)"
      case .unreadable: "unreadable"
      case .files: "files"
      }
    }

    public var text: String {
      switch self {
      case .drafts(let text), .waiting(let text), .failed(let text), .notice(_, let text),
        .unreadable(let text), .files(let text):
        text
      }
    }
  }

  public let rows: [Row]

  public init(
    drafts: [DiveDraftEntry], items: [OutboxItem], notices: [OutboxNotice], unreadable: Int,
    files: Int
  ) {
    var rows: [Row] = []
    if !drafts.isEmpty { rows.append(.drafts(PendingText.drafts(drafts.count))) }
    if let waiting = PendingText.waiting(items) { rows.append(.waiting(waiting)) }
    let failed = items.filter(\.isFailed).count
    if failed > 0 { rows.append(.failed(PendingText.failed(failed))) }
    rows += notices.map { .notice(id: $0.id, $0.sentence) }
    if unreadable > 0 { rows.append(.unreadable(PendingText.unreadable(unreadable))) }
    if files > 0 { rows.append(.files(PendingText.filesWaiting(files))) }
    self.rows = rows
  }

  public var isEmpty: Bool { rows.isEmpty }
}

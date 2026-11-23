import Foundation

/// Which of a Suunto Nautic-family watch's logbook entries a walk counts and downloads, decided
/// from each entry's summary before any profile is read.
///
/// The logbook lists every activity the watch recorded, runs beside dives. An entry is counted
/// and downloaded as a dive where its summary names a diving sport, names none, does not fit the
/// descriptors or could not be fetched — a dive wrongly skipped is never walked again once the
/// fingerprint moves past it. An entry whose summary answered with no bytes is not counted, most
/// such entries holding nothing, but is still downloaded, its profile possibly a dive. A new
/// entry whose dive the phone need not take again is walked as a run is, and not counted new.
public struct NauticSelection: Hashable, Sendable {
  /// What a walk learned of one entry's summary.
  public enum Summary: Hashable, Sendable {
    /// Read: the sport it names against the descriptors, or nil where it names none or does not
    /// fit them (``NauticDescriptors/sport(inSummary:)``), how long the entry lasted where it
    /// says (``NauticDescriptors/duration(inSummary:)``), and what it says of the dive
    /// (``NauticDescriptors/facts(inSummary:id:)``).
    case read(sport: Int?, duration: Double? = nil, facts: ListedDiveFacts? = nil)
    /// Answered with no bytes.
    case empty
    /// Not fetched.
    case unread
  }

  /// What the walk does with one new entry.
  public enum Fate: Hashable, Sendable {
    /// A non-diving sport: yielded as skipped, its profile never read.
    case skip
    /// Its dive is one the phone need not take again: yielded as skipped, its profile not read
    /// again.
    case waiting
    /// Downloaded and handed on as a dive.
    case download
  }

  public struct Entry: Hashable, Sendable {
    public let id: UInt32
    public let fate: Fate
    /// Counted among the dives: false for an entry whose summary answered empty, which is
    /// downloaded all the same.
    public let counted: Bool
  }

  /// The new entries, newest first, each with its fate.
  public let entries: [Entry]
  /// The count, with the sports for the record: those the record remembered and those read,
  /// for the listed entries only.
  public let listing: DiveComputerListing
  /// The listed entries counted as dives that the walk does not download among ``listing``'s,
  /// newest first: those behind the fingerprint and those whose dive the phone need not take
  /// again.
  public let others: [DiveComputerListing.Download]

  /// The listed entries whose summary the walk reads: those `remembered` does not name, and those
  /// it names as a dive without the facts a summary gives, kept before they were read.
  public static func summariesNeeded(ids: [UInt32], remembered: [NauticEntrySport]?) -> [UInt32] {
    let known = Set((remembered ?? []).filter { $0.facts != nil || !$0.isDive }.map(\.id))
    return ids.filter { !known.contains($0) }
  }

  /// `ids` are the logbook's, newest first; the new entries are those before the one whose four
  /// little-endian bytes equal `fingerprint`, or every one where none does, as libdivecomputer's
  /// walk compares. `learned` holds what this walk read of the summaries, which stands over what
  /// `remembered` names where the summary was read; an entry in neither counts as unread. `waiting` says whether an entry's dive is one
  /// the phone need not take again.
  public init(
    ids: [UInt32], fingerprint: Data?, remembered: [NauticEntrySport]?,
    learned: [UInt32: Summary], waiting: (UInt32) -> Bool = { _ in false }
  ) {
    let known = Dictionary(
      (remembered ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let summaries: [Summary] = ids.map { id in
      if let summary = learned[id], case .read = summary { return summary }
      if let entry = known[id] {
        return .read(sport: entry.sport, duration: entry.duration, facts: entry.facts)
      }
      return learned[id] ?? .unread
    }
    let stop = fingerprint.flatMap { mark in ids.firstIndex { Self.fingerprint($0) == mark } }
    let newCount = stop ?? ids.count
    let new = zip(ids, summaries).prefix(newCount)
    let entries = new.map { id, summary in
      let fate = Self.fate(summary)
      return Entry(
        id: id, fate: fate == .download && waiting(id) ? .waiting : fate,
        counted: Self.counts(summary))
    }
    self.entries = entries
    let counted = summaries.map(Self.counts)
    let read = zip(ids, summaries).compactMap { id, summary -> NauticEntrySport? in
      guard case .read(let sport, let duration, let facts) = summary else { return nil }
      return NauticEntrySport(id: id, sport: sport, duration: duration, facts: facts)
    }
    let remembered = Dictionary(read.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    // An uncounted entry is left out: its download most often answers empty and yields nothing,
    // which would leave it to come for the rest of the walk.
    let downloads = entries.filter { $0.counted && $0.fate == .download }.map(\.id)
    listing = DiveComputerListing(
      dives: counted.count { $0 },
      newDives: downloads.count,
      sports: read,
      downloads: downloads.map {
        DiveComputerListing.Download(
          fingerprint: Self.fingerprint($0), facts: Self.facts($0, remembered[$0]))
      })
    let taken = Set(downloads)
    others = zip(ids, summaries).compactMap { id, summary in
      guard !taken.contains(id), Self.counts(summary), Self.fate(summary) == .download else {
        return nil
      }
      return DiveComputerListing.Download(
        fingerprint: Self.fingerprint(id), facts: Self.facts(id, remembered[id]))
    }
  }

  /// The ids of `ids`, the logbook's, newest first, whose fingerprints are in `catchUp`.
  public static func taking(_ catchUp: Set<Data>, of ids: [UInt32]) -> [UInt32] {
    ids.filter { catchUp.contains(fingerprint($0)) }
  }

  /// What the list says of an entry's dive: its start, the id, whatever its summary gave; the
  /// summary's length and depth; a length from ``NauticEntrySport/duration`` where the facts were
  /// not read.
  private static func facts(_ id: UInt32, _ summary: NauticEntrySport?) -> ListedDiveFacts {
    var facts = summary?.facts ?? ListedDiveFacts()
    if facts.start == nil {
      facts.start = .instant(Date(timeIntervalSince1970: TimeInterval(id)), offsetSeconds: nil)
    }
    if facts.length == nil { facts.length = summary?.duration }
    return facts
  }

  /// The fingerprint libdivecomputer's walk gives an entry: its id's four little-endian bytes.
  public static func fingerprint(_ id: UInt32) -> Data {
    Data((0..<4).map { UInt8(truncatingIfNeeded: id >> (8 * $0)) })
  }

  private static func counts(_ summary: Summary) -> Bool {
    switch summary {
    case .read(let sport, _, _): sport.map(NauticSport.diving.contains) ?? true
    case .empty: false
    case .unread: true
    }
  }

  private static func fate(_ summary: Summary) -> Fate {
    switch summary {
    case .read(let sport?, _, _) where !NauticSport.diving.contains(sport): .skip
    default: .download
    }
  }
}

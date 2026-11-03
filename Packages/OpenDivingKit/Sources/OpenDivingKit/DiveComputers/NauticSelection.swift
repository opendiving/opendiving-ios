import Foundation

/// Which of a Suunto Nautic-family watch's logbook entries a walk counts and downloads, decided
/// from each entry's summary before any profile is read.
///
/// The logbook lists every activity the watch recorded, runs beside dives. An entry is counted
/// and downloaded as a dive where its summary names a diving sport, names none, does not fit the
/// descriptors or could not be fetched — a dive wrongly skipped is never walked again once the
/// fingerprint moves past it. An entry whose summary answered with no bytes is not counted, most
/// such entries holding nothing, but is still downloaded, its profile possibly a dive. A new
/// entry whose dive already waits in the import screen is walked as a run is, and not counted
/// new.
public struct NauticSelection: Hashable, Sendable {
  /// What a walk learned of one entry's summary.
  public enum Summary: Hashable, Sendable {
    /// Read: the sport it names against the descriptors, or nil where it names none or does not
    /// fit them (``NauticDescriptors/sport(inSummary:)``).
    case read(sport: Int?)
    /// Answered with no bytes.
    case empty
    /// Not fetched.
    case unread
  }

  /// What the walk does with one new entry.
  public enum Fate: Hashable, Sendable {
    /// A non-diving sport: yielded as skipped, its profile never read.
    case skip
    /// Its dive already waits in the import screen: yielded as skipped, its profile not read
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

  /// The listed entries whose summary the walk reads: those `remembered` does not name.
  public static func summariesNeeded(ids: [UInt32], remembered: [NauticEntrySport]?) -> [UInt32] {
    let known = Set((remembered ?? []).map(\.id))
    return ids.filter { !known.contains($0) }
  }

  /// `ids` are the logbook's, newest first; the new entries are those before the one whose four
  /// little-endian bytes equal `fingerprint`, or every one where none does, as libdivecomputer's
  /// walk compares. `learned` holds what this walk read of the summaries `remembered` did not
  /// name; an entry in neither counts as unread. `waiting` says whether an entry's dive already
  /// waits in the import screen.
  public init(
    ids: [UInt32], fingerprint: Data?, remembered: [NauticEntrySport]?,
    learned: [UInt32: Summary], waiting: (UInt32) -> Bool = { _ in false }
  ) {
    let known = Dictionary(
      (remembered ?? []).map { ($0.id, $0.sport) }, uniquingKeysWith: { first, _ in first })
    let summaries: [Summary] = ids.map { id in
      if let sport = known[id] { return .read(sport: sport) }
      return learned[id] ?? .unread
    }
    let stop = fingerprint.flatMap { mark in ids.firstIndex { Self.fingerprint($0) == mark } }
    let newCount = stop ?? ids.count
    let entries = zip(ids, summaries).prefix(newCount).map { id, summary in
      let fate = Self.fate(summary)
      return Entry(
        id: id, fate: fate == .download && waiting(id) ? .waiting : fate,
        counted: Self.counts(summary))
    }
    self.entries = entries
    let counted = summaries.map(Self.counts)
    listing = DiveComputerListing(
      dives: counted.count { $0 },
      newDives: entries.count { $0.counted && $0.fate == .download },
      newEntries: newCount,
      sports: zip(ids, summaries).compactMap { id, summary in
        guard case .read(let sport) = summary else { return nil }
        return NauticEntrySport(id: id, sport: sport)
      })
  }

  /// The fingerprint libdivecomputer's walk gives an entry: its id's four little-endian bytes.
  public static func fingerprint(_ id: UInt32) -> Data {
    Data((0..<4).map { UInt8(truncatingIfNeeded: id >> (8 * $0)) })
  }

  private static func counts(_ summary: Summary) -> Bool {
    switch summary {
    case .read(let sport): sport.map(NauticSport.diving.contains) ?? true
    case .empty: false
    case .unread: true
    }
  }

  private static func fate(_ summary: Summary) -> Fate {
    switch summary {
    case .read(let sport?) where !NauticSport.diving.contains(sport): .skip
    default: .download
    }
  }
}

import Foundation

/// One dive draft as *Log a dive* offers it, the way the web's Drafts card names it: by its start,
/// or *Untitled draft*, then its first site and when it last changed.
public struct DiveDraftRowContent: Hashable, Sendable, Identifiable {
  public var id: RecordRef { ref }
  public let ref: RecordRef
  public let title: String
  public let detail: String
  /// A change of the phone's has not reached the server yet.
  public let isPending: Bool

  public init(_ entry: DiveDraftEntry, siteName: String?, timeZone: TimeZone = .current) {
    ref = entry.ref
    title = entry.write.values.startTime.map(DateText.diveDateTime) ?? "Untitled draft"
    detail =
      (siteName.map { "\($0) · " } ?? "") + "Changed "
      + DateText.dateTime(entry.changedAt, in: timeZone)
    isPending = entry.hasPendingChange
  }

  /// The drafts in the order given, each with its first site named from `sites` where the
  /// phone knows it.
  public static func rows(
    _ drafts: [DiveDraftEntry], sites: [DiveSiteLookupItem], timeZone: TimeZone = .current
  ) -> [DiveDraftRowContent] {
    let names = Dictionary(sites.map { ($0.ref, $0.name) }, uniquingKeysWith: { a, _ in a })
    return drafts.map { entry in
      DiveDraftRowContent(
        entry, siteName: entry.write.values.diveSites?.first.flatMap { names[$0] },
        timeZone: timeZone)
    }
  }
}

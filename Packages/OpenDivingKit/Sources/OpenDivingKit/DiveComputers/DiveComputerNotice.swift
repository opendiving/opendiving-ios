import Foundation

/// A notification about a download, made on the phone: its words and what a tap opens. Built
/// from the import's answer, or from why the dives still wait.
public struct DiveComputerNotice: Hashable, Sendable {
  public enum Target: Hashable, Sendable {
    case dive(UUID)
    case importPage(UUID)
    case diveComputers

    /// The target as a notification carries it, in plain strings.
    public var userInfo: [String: String] {
      switch self {
      case .dive(let uuid): ["open": "dive", "uuid": uuid.uuidString.lowercased()]
      case .importPage(let uuid): ["open": "import", "uuid": uuid.uuidString.lowercased()]
      case .diveComputers: ["open": "dive-computers"]
      }
    }

    /// The target a notification carries; nil for one that carries none.
    public init?(userInfo: [AnyHashable: Any]) {
      let uuid = (userInfo["uuid"] as? String).flatMap(UUID.init(uuidString:))
      switch userInfo["open"] as? String {
      case "dive":
        guard let uuid else { return nil }
        self = .dive(uuid)
      case "import":
        guard let uuid else { return nil }
        self = .importPage(uuid)
      case "dive-computers": self = .diveComputers
      default: return nil
      }
    }
  }

  /// One per download and kind, so a repeat replaces rather than adds.
  public let id: String
  public let title: String
  public let body: String
  public let target: Target
  /// Only recordings were added: nothing new to look at, so it does not light the screen.
  public let passive: Bool

  public init(id: String, title: String, body: String, target: Target, passive: Bool = false) {
    self.id = id
    self.title = title
    self.body = body
    self.target = target
    self.passive = passive
  }

  /// What a download's applied imports say together, from the rows they answered: their new
  /// dives, the recordings they added to dives already in the logbook, the dives `updating` names
  /// that they changed — those the download took the computer's original to — or any of them
  /// together; nil where they did none of it. A tap opens the one new dive, or the one updated
  /// dive told alone, else the one import's page, else the Dive Computers screen, where there are
  /// several imports and no page shows them all. `download` names the download.
  public static func imported(
    _ rows: [LogbookImportDive], imports: [UUID], download: UUID, from computer: String,
    updating: Set<UUID> = [], units: UnitSystem
  ) -> DiveComputerNotice? {
    let new = rows.filter { $0.outcome == "new" }
    let modified = rows.filter { $0.outcome == "modified" }
    var seen: Set<UUID> = []
    let updated = modified.filter { row in
      guard let uuid = Self.uuid(row), updating.contains(uuid) else { return false }
      return seen.insert(uuid).inserted
    }
    let added = modified.filter { Self.uuid($0).map { !updating.contains($0) } ?? true }
    let id = "import-" + download.uuidString.lowercased()
    let page: Target = imports.count == 1 ? .importPage(imports[0]) : .diveComputers
    let downloaded = "Downloaded from \(computer)."
    let others =
      updated.isEmpty
      ? nil
      : updated.count == 1 ? "1 other dive updated." : "\(updated.count) other dives updated."
    if new.isEmpty, added.isEmpty {
      guard !updated.isEmpty else { return nil }
      let one = updated.count == 1
      let body =
        (one
          ? facts(updated[0], units: units)
          : days(updated.compactMap { $0.startTime ?? $0.dive?.dive.startTime }))
        .map { $0 + ". " } ?? ""
      return DiveComputerNotice(
        id: id, title: one ? "1 dive updated" : "\(updated.count) dives updated",
        body: body + downloaded,
        target: one ? Self.uuid(updated[0]).map(Target.dive) ?? page : page, passive: true)
    }
    if new.isEmpty {
      let body =
        added.count == 1
        ? "\(computer) also recorded your dive of \(when(added[0]) ?? "")."
        : "\(computer) also recorded \(added.count) dives already in your logbook."
      return DiveComputerNotice(
        id: id,
        title: added.count == 1
          ? "Recording added to 1 dive" : "Recordings added to \(added.count) dives",
        body: others.map { body + " " + $0 } ?? body, target: page, passive: true)
    }
    let title = new.count == 1 ? "1 new dive imported" : "\(new.count) new dives imported"
    let told = others.map { $0 + " " + downloaded } ?? downloaded
    let body: String
    if !added.isEmpty {
      body =
        (added.count == 1
          ? "A recording was added to 1 other dive."
          : "Recordings were added to \(added.count) other dives.") + " " + told
    } else if new.count == 1 {
      body = (facts(new[0], units: units).map { $0 + ". " } ?? "") + told
    } else {
      body = (days(new.compactMap(\.startTime)).map { $0 + ". " } ?? "") + told
    }
    let target: Target =
      new.count == 1 && added.isEmpty
      ? Self.uuid(new[0]).map(Target.dive) ?? page
      : page
    return DiveComputerNotice(id: id, title: title, body: body, target: target)
  }

  /// No route: the dives wait on the phone.
  public static func noInternet(dives: Int, from computer: String, id: UUID) -> DiveComputerNotice {
    DiveComputerNotice(
      id: "waiting-" + id.uuidString.lowercased(),
      title: dives == 1 ? "1 dive downloaded" : "\(dives) dives downloaded",
      body:
        "No internet. The dives from \(computer) will be imported when the phone is online again.",
      target: .diveComputers)
  }

  /// Nobody signed in: the dives wait for a sign-in.
  public static func signedOut(dives: Int, from computer: String, id: UUID) -> DiveComputerNotice {
    DiveComputerNotice(
      id: "waiting-" + id.uuidString.lowercased(),
      title: dives == 1 ? "Sign in to import 1 dive" : "Sign in to import \(dives) dives",
      body: "Downloaded from \(computer). The dives stay on this phone until you sign in.",
      target: .diveComputers)
  }

  /// Dives that wait for the diver's time zone.
  public static func timeZone(dives: Int, from computer: String, id: UUID) -> DiveComputerNotice {
    DiveComputerNotice(
      id: "zone-" + id.uuidString.lowercased(),
      title: DiveComputerText.chooseTimeZone(dives),
      body:
        "Downloaded from \(computer). Tap to choose the time zone and import "
        + (dives == 1 ? "it." : "them."),
      target: .diveComputers)
  }

  // MARK: - Pieces

  /// The row's dive: a new one as it will be written, or the logbook's it changed.
  private static func uuid(_ row: LogbookImportDive) -> UUID? {
    row.uuid ?? row.dive?.dive.uuid
  }

  /// *12 October, 09:41 · 28.4 m · 46 min*.
  private static func facts(_ row: LogbookImportDive, units: UnitSystem) -> String? {
    guard let when = when(row) else { return nil }
    var parts = [when]
    if let depth = row.dive?.dive.maxDepth {
      parts.append(UnitFormat.depth(depth, units, decimals: 1))
    }
    if let seconds = row.dive?.dive.submergedTime, seconds > 0 {
      parts.append("\(Int((Double(seconds) / 60).rounded())) min")
    }
    return parts.joined(separator: " · ")
  }

  /// *12 October, 09:41*, on the dive's own clock.
  private static func when(_ row: LogbookImportDive) -> String? {
    guard let start = row.startTime ?? row.dive?.dive.startTime else { return nil }
    let date = start.calendarDate
    let day = "\(date.day) \(DiveComputerText.months[date.month - 1])"
    guard let clock = start.wallClock else { return day }
    return day + ", " + CalendarDate.pad(clock.hour, 2) + ":" + CalendarDate.pad(clock.minute, 2)
  }

  /// *12–14 October*, one day where the dives share it, and both months where they differ.
  private static func days(_ starts: [DiveTimestamp]) -> String? {
    let dates = starts.map(\.calendarDate)
    guard let first = dates.min(), let last = dates.max() else { return nil }
    let month = { (date: CalendarDate) in DiveComputerText.months[date.month - 1] }
    if first == last { return "\(first.day) \(month(first))" }
    if first.month == last.month, first.year == last.year {
      return "\(first.day)–\(last.day) \(month(first))"
    }
    return "\(first.day) \(month(first))–\(last.day) \(month(last))"
  }
}

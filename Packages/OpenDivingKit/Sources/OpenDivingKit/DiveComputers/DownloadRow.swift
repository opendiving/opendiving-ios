import Foundation

/// One dive of a download on its way to the logbook, drawn as a dive card above the logbook's
/// dives until its import is answered: a dive the walk in flight will still take, or one on the
/// phone the server has not answered for (``DiveComputerEngine/downloadRows(units:phoneZone:)``).
public struct DownloadRow: Hashable, Sendable, Identifiable {
  /// What the dive waits for, in one line.
  public enum Line: Hashable, Sendable {
    /// Being read from the computer, or sent: nothing holds it back.
    case syncing
    /// Still on the computer, behind the dive being read.
    case waiting
    case waitingForInternet
    case waitingForSignIn
    /// The time zone's question or the computers' order holds it.
    case waitingForAnswer
    /// The server refused its archive.
    case couldNotImport

    /// What holds a dive on the phone, as its line: a dive with a route, a sign-in and no
    /// question is on its way, whether it goes with the next upload, at its walk's end or at the
    /// next try.
    public init(_ wait: DiveOnPhone.Wait) {
      switch wait {
      case .nothing, .walkEnd, .retry: self = .syncing
      case .route: self = .waitingForInternet
      case .signIn: self = .waitingForSignIn
      case .timeZone, .order: self = .waitingForAnswer
      case .refused: self = .couldNotImport
      }
    }

    public var text: String {
      switch self {
      case .syncing: DownloadRowText.syncing
      case .waiting: DownloadRowText.waiting
      case .waitingForInternet: DownloadRowText.waitingForInternet
      case .waitingForSignIn: DownloadRowText.waitingForSignIn
      case .waitingForAnswer: DownloadRowText.waitingForAnswer
      case .couldNotImport: DownloadRowText.couldNotImport
      }
    }
  }

  /// Where tapping the row leads: where the diver can act on what holds the dive.
  public enum Opens: Hashable, Sendable {
    /// *Dive Computers*: the walk in flight, or the question that holds the dive.
    case diveComputers
    /// *Waiting to Sync*, whose downloads section sends again or removes the archive.
    case waitingToSync
  }

  /// A dive the walk in flight will still take, as its queue lists it.
  public struct Listed: Hashable, Sendable {
    /// The uuid it will be imported under, where the computer has identified itself.
    public let uuid: UUID?
    /// The fingerprint it is listed under.
    public let fingerprint: Data
    /// *Shearwater Perdix 3*.
    public let computer: String
    public let facts: ListedDiveFacts
    /// The zone its watch reported, for showing an instant with no offset.
    public let watchZone: TimeZone?
    /// It is the dive being read now.
    public let inTransfer: Bool

    public init(
      uuid: UUID?, fingerprint: Data, computer: String, facts: ListedDiveFacts,
      watchZone: TimeZone?, inTransfer: Bool
    ) {
      self.uuid = uuid
      self.fingerprint = fingerprint
      self.computer = computer
      self.facts = facts
      self.watchZone = watchZone
      self.inTransfer = inTransfer
    }
  }

  /// The dive's uuid where it is known, else its fingerprint's hex.
  public let id: String
  public let line: Line
  public let opens: Opens
  public let card: DiveCardContent

  /// One row for each dive, newest first by the start shown, the dives whose start nobody listed
  /// after them in the order given: the walk's queue, then the dives on the phone. A dive on the
  /// phone that the queue still lists has the queue's row.
  public static func rows(
    onComputer: [Listed], onPhone: [DiveOnPhone], units: UnitSystem,
    phoneZone: TimeZone = .current
  ) -> [DownloadRow] {
    var seen: Set<String> = []
    var rows: [(row: DownloadRow, start: LocalDateTime?)] = []
    func add(
      id: String, computer: String, facts: ListedDiveFacts?, watchZone: TimeZone?, line: Line,
      opens: Opens
    ) {
      guard seen.insert(id).inserted else { return }
      let start = facts?.shownStart(watchZone: watchZone, phoneZone: phoneZone)
      let card = DiveCardContent.download(
        computer: computer, start: start, facts: facts, line: line, units: units)
      rows.append((DownloadRow(id: id, line: line, opens: opens, card: card), start?.wallClock))
    }
    for dive in onComputer {
      add(
        id: dive.uuid?.uuidString ?? Hex.lowercase(dive.fingerprint), computer: dive.computer,
        facts: dive.facts, watchZone: dive.watchZone, line: dive.inTransfer ? .syncing : .waiting,
        opens: .diveComputers)
    }
    for dive in onPhone {
      // No archive yet: the walk in flight keeps it, or the time zone's question holds it.
      let asks = dive.archive == nil || dive.wait == .order
      add(
        id: dive.id.uuidString, computer: dive.computer, facts: dive.facts,
        watchZone: dive.watchZone, line: Line(dive.wait),
        opens: asks ? .diveComputers : .waitingToSync)
    }
    return rows.enumerated().sorted { lhs, rhs in
      switch (lhs.element.start, rhs.element.start) {
      case (let left?, let right?) where left != right: left > right
      case (.some, nil): true
      case (nil, .some): false
      default: lhs.offset < rhs.offset
      }
    }.map(\.element.row)
  }
}

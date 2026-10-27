import Foundation
import Observation

/// The import screen's model over the inbox of the account the session names: files in, the
/// reads, the apply.
///
/// **When a read runs.** Every read sends every waiting file, against a counter of imports an
/// hour the apply shares, so the app reads on its own only to cover an inbox no read covers —
/// once the account has loaded in this process, when a file arrives into it, and at the
/// connectivity seam's moments — and never while the account is unknown, when the inbox it
/// would read could be another account's, nor while the session's connectivity reports no
/// route: the files wait for the moment one appears. A change to a covered inbox marks its read
/// stale and the next read is the diver's tap, which tries with or without a route. One read
/// runs at a time; a file arriving during one is covered by one more when it is answered, and a
/// read that never reached the server leaves nothing and starts nothing.
@MainActor
@Observable
public final class InboxModel {
  public enum Phase: Hashable, Sendable {
    case idle, reading, importing
  }

  /// Where a file handed to the app went.
  public enum Intake: Hashable, Sendable {
    /// Into the inbox of `account`; `signedIn` says whether the session can read it now.
    case kept(account: UUID, signedIn: Bool)
    /// Nowhere, and why, in a sentence for the diver.
    case notKept(String)
  }

  public static let noAccountSentence = "Choose a server and sign in, then share the file again."
  public static let accountLoadingSentence = "Your account is still loading; share the file again."

  public private(set) var files: [InboxFile] = []
  public private(set) var read: InboxRead?
  public private(set) var phase = Phase.idle
  /// The last apply's answer, shown in place of the review until ``dismissResult()``.
  public private(set) var result: ImportResult?
  /// The result's numbering sentence, where the import tangled the log's numbering.
  public private(set) var resultNumbering: String?
  /// Why the last apply failed.
  public private(set) var applyError: String?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var readTask: Task<Void, Never>?
  @ObservationIgnored private var applyTask: Task<Void, Never>?
  /// A file arrived during the read in flight.
  @ObservationIgnored private var followUp = false
  @ObservationIgnored private var shownAccount: UUID?

  public init(session: Session) {
    self.session = session
    reload()
  }

  // MARK: - What the screen shows

  /// Whether the account has loaded in this process, so reads and imports can run.
  public var isAccountLoaded: Bool { session.accountLoaded }

  /// The units the rows print in: the account's, or as last read while it is unknown.
  public var units: UnitSystem {
    if session.accountLoaded { return session.units }
    guard let origin = session.state.origin, let account = destination?.store.account,
      let settings = session.store.formSettings(for: origin, account: account)
    else { return session.units }
    return settings.units
  }

  /// Why one file is left out of every read, or nil.
  public func refusal(for file: InboxFile) -> String? {
    ImportBounds.fileRefusal(filename: file.filename, byteSize: file.byteSize)
  }

  /// The files a read sends: every waiting file the bounds do not refuse.
  public var sendable: [InboxFile] { files.filter { refusal(for: $0) == nil } }

  /// Why the files cannot go as one import, or nil.
  public var selectionRefusal: String? {
    ImportBounds.selectionRefusal(byteSizes: sendable.map(\.byteSize))
  }

  /// *2 files waiting; they are read when the server can be reached*, while no read covers the
  /// inbox, the files can go as one import and there is no route to start one over.
  public var waitingForRoute: String? {
    guard session.accountLoaded, phase == .idle, read == nil, !sendable.isEmpty,
      selectionRefusal == nil, !session.connectivity.isRouteAvailable
    else { return nil }
    return ImportText.waitingForRoute(sendable.count)
  }

  /// Whether *Read the files* can be tapped.
  public var canRead: Bool {
    session.accountLoaded && phase == .idle && !sendable.isEmpty && selectionRefusal == nil
  }

  /// The preview *Import* applies, when one is held and nothing has changed since.
  public var importable: ImportPreview? {
    guard let read, read.isImportable else { return nil }
    return read.preview
  }

  /// The row of `members` a waiting file became in the read on screen, and the rows of the
  /// files a zip of it opened into.
  public func members(of file: InboxFile) -> (
    own: ImportMemberReport?, inside: [ImportMemberReport]
  ) {
    guard let read, !read.stale, let preview = read.preview,
      let part = read.files.firstIndex(of: file.id),
      let row = preview.members.firstIndex(where: { $0.part == part && $0.container == nil })
    else { return (nil, []) }
    return (preview.members[row], preview.members.filter { $0.container == row })
  }

  // MARK: - Files in

  /// Takes files handed to the app into the inbox the session names, as one arrival:
  /// `moving` for the copy iOS made for the app, otherwise copied. Signed in before the
  /// account has loaded, the inbox is the last account's and the files are marked; with no
  /// such account, or no server, they are kept nowhere. `download` marks an archive
  /// downloaded from dive computers.
  @discardableResult
  public func receive(_ urls: [URL], moving: Bool, download: InboxDownload? = nil) -> Intake {
    guard let destination else {
      if case .signedIn = session.state { return .notKept(Self.accountLoadingSentence) }
      return .notKept(Self.noAccountSentence)
    }
    let store = destination.store
    var contents = store.load()
    var added: [InboxFile] = []
    var failure: (any Error)?
    for url in urls {
      do {
        added.append(
          try store.take(url, moving: moving, marked: destination.marked, download: download))
      } catch {
        failure = error
      }
    }
    guard !added.isEmpty else {
      return .notKept(
        "The file could not be kept on this phone: \(failure.map(String.init(describing:)) ?? "nothing was shared")."
      )
    }
    contents.files += added
    if contents.read != nil { contents.read?.stale = true }
    do {
      try store.save(contents)
    } catch {
      store.discard(added)
      return .notKept("The file could not be kept on this phone: \(error).")
    }
    reload()
    if !destination.marked, contents.read == nil { startRead(arrival: true) }
    let signedIn = if case .signedIn = session.state { true } else { false }
    return .kept(account: store.account, signedIn: signedIn)
  }

  /// Whether *Remove* asks first: a download archive is the only copy of its dives.
  public func removalNeedsConfirmation(_ file: InboxFile) -> Bool { file.download != nil }

  /// Whether *Remove all* asks first.
  public var removeAllNeedsConfirmation: Bool { files.contains { $0.download != nil } }

  /// Replaces download archives waiting unimported with their union, in one save: the union
  /// taken in and recorded and the waiting files' records dropped together, their bytes
  /// discarded only after it, so a failed take leaves them where they were. Acts only while
  /// the inbox is idle and every one of `waiting` is still in it, as a swap under a read or an
  /// apply would pull the files out from under it; nil otherwise, for the caller to try again.
  func replaceDownloads(_ waiting: [InboxFile], with union: URL, download: InboxDownload)
    -> Intake?
  {
    guard phase == .idle, let destination else { return nil }
    let store = destination.store
    var contents = store.load()
    let ids = Set(waiting.map(\.id))
    guard ids.isSubset(of: contents.files.map(\.id)) else { return nil }
    let taken: InboxFile
    do {
      taken = try store.take(union, moving: true, marked: destination.marked, download: download)
    } catch {
      return .notKept("The file could not be kept on this phone: \(error).")
    }
    contents.files.removeAll { ids.contains($0.id) }
    contents.files.append(taken)
    settleRead(&contents)
    if contents.read != nil { contents.read?.stale = true }
    do {
      try store.save(contents)
    } catch {
      store.discard([taken])
      return .notKept("The file could not be kept on this phone: \(error).")
    }
    store.discard(waiting)
    reload()
    if !destination.marked, contents.read == nil { startRead(arrival: true) }
    let signedIn = if case .signedIn = session.state { true } else { false }
    return .kept(account: store.account, signedIn: signedIn)
  }

  /// The account a file handed over now is kept for, and whether it is marked as received
  /// before the account was known; nil where nothing would be kept.
  var keeping: (account: UUID, marked: Bool)? {
    destination.map { ($0.store.account, $0.marked) }
  }

  /// The download archives waiting in that inbox with the given mark.
  func waitingDownloads(marked: Bool) -> [InboxFile] {
    guard let store = destination?.store else { return [] }
    return store.load().files.filter {
      $0.download != nil && $0.receivedBeforeAccountKnown == marked
    }
  }

  /// Whether that inbox holds a full-export archive that is not a download — one the diver
  /// shared — which would make a download's the second archive of one import. Read from each
  /// waiting zip's central directory, never from the server.
  var holdsSharedArchive: Bool {
    guard let store = destination?.store else { return false }
    return store.load().files.contains {
      $0.download == nil && ZipReader.isFullExport(store.url(for: $0))
    }
  }

  /// Where a file in that inbox keeps its bytes.
  func url(for file: InboxFile) -> URL? { destination?.store.url(for: file) }

  /// Removes one waiting file. Reads nothing: the read on screen goes stale.
  public func remove(_ file: InboxFile) {
    guard phase == .idle, let store = destination?.store else { return }
    var contents = store.load()
    contents.files.removeAll { $0.id == file.id }
    settleRead(&contents)
    try? store.save(contents)
    store.discard([file])
    reload()
  }

  /// Empties the inbox, which leaves it uncovered: the next file is a batch's first.
  public func removeAll() {
    guard phase == .idle, let store = destination?.store else { return }
    let contents = store.load()
    try? store.save(InboxStore.Contents())
    store.discard(contents.files)
    reload()
  }

  // MARK: - Reads

  /// The diver's *Read the files* and *Read the files again*.
  public func readAgain() {
    guard phase == .idle else { return }
    startRead(arrival: false, tapped: true)
  }

  /// A connectivity moment: reads an inbox no read covers, and nothing else.
  public func handle(_ moment: ConnectivityMoment) {
    guard phase == .idle, read == nil, !files.isEmpty else { return }
    startRead(arrival: false)
  }

  /// Reads on every moment the session's connectivity reports, until cancelled.
  public func watch() async {
    for await moment in session.connectivity.moments() {
      handle(moment)
    }
  }

  /// The session changed — signed in or out, or the account loaded. A load moves the files
  /// received before it into the loaded account's inbox, and removes the dive computers'
  /// records written before it for any other account; a session that ended before one leaves
  /// them where they are. Then an uncovered inbox is read.
  public func sessionChanged() {
    if let origin = session.state.origin {
      let inboxes = InboxStore.all(store: session.store, origin: origin)
      switch session.state {
      case .signingIn:
        for inbox in inboxes { try? inbox.clearMarks() }
        for computers in DiveComputerStore.all(store: session.store, origin: origin) {
          try? computers.clearMarks()
        }
      case .signedIn where session.accountLoaded:
        if let user = session.user {
          let mine = InboxStore(store: session.store, origin: origin, account: user.uuid)
          for other in inboxes where other.account != user.uuid {
            _ = try? mine.takeMarked(from: other)
          }
          try? mine.clearMarks()
          // A computer's record written before the load stays only with the account it was
          // written for: moved, it would carry that account's fingerprint into this one's.
          for computers in DiveComputerStore.all(store: session.store, origin: origin) {
            if computers.account == user.uuid {
              try? computers.clearMarks()
            } else {
              computers.removeMarked()
            }
          }
        }
      default:
        break
      }
    }
    reload()
    if phase == .idle, read == nil, !files.isEmpty { startRead(arrival: false) }
  }

  /// Waits for the read or the import in flight, and any read it started.
  public func settled() async {
    while let task = readTask ?? applyTask {
      await task.value
    }
  }

  // MARK: - Import

  /// The diver's *Import*: the files the preview was read from, in the order read, under the
  /// same names, with its token and the check-in choices.
  public func apply(_ choices: ImportCheckInChoices) {
    guard phase == .idle, session.accountLoaded, let read, let preview = read.preview,
      !read.stale, let store = destination?.store, let client = try? session.requireClient()
    else { return }
    let contents = store.load()
    let sent = read.files.compactMap { id in contents.files.first { $0.id == id } }
    guard sent.count == read.files.count else {
      var changed = contents
      changed.read?.stale = true
      try? store.save(changed)
      reload()
      return
    }
    phase = .importing
    applyError = nil
    applyTask = Task {
      let reread = await perform(choices, preview: preview, read: read, sent: sent, store, client)
      phase = .idle
      applyTask = nil
      if reread { startRead(arrival: false) }
    }
  }

  /// The apply itself; true when the files left waiting are to be read again: the API asked
  /// for it, or a refused download archive stays.
  private func perform(
    _ choices: ImportCheckInChoices, preview: ImportPreview, read: InboxRead, sent: [InboxFile],
    _ store: InboxStore, _ client: APIClient
  ) async -> Bool {
    do {
      let result = try await client.importApply(
        files: sent.map { ImportFile(file: store.url(for: $0), filename: $0.filename) },
        token: preview.token, checkInDetails: choices.submission(for: preview.checkInDetails),
        portrait: choices.portrait(for: preview.portrait))
      let after = try? await client.diveNumbering()
      // A download archive whose own row the import refused is the only copy of its dives,
      // so it stays to be read again alone; every other file sent goes, another copy of a
      // shared file existing wherever it was shared from.
      let kept = Set(
        sent.enumerated().filter { part, file in
          file.download != nil
            && result.members.contains {
              $0.part == part && $0.container == nil && $0.refusal != nil
            }
        }.map(\.element.id))
      var now = store.load()
      let imported = Set(read.files).subtracting(kept)
      now.files.removeAll { imported.contains($0.id) }
      now.read = nil
      try? store.save(now)
      store.discard(sent.filter { !kept.contains($0.id) })
      reload()
      if let stores = AccountStores.current(session) {
        OutboxHub.hub(for: stores.directory).listsChanged()
      }
      self.result = result
      resultNumbering = ImportText.numberingSuggestion(
        before: read.numbering, after: after, dives: result.dives)
      return !kept.isEmpty
    } catch let error as APIError {
      if case .http(422, let message) = error, Self.isStalePreview(message) { return true }
      if case .http(_, let message) = error {
        applyError = message ?? ImportText.applyFailed
      } else {
        applyError = error.message
      }
    } catch {
      applyError = ImportText.applyFailed
    }
    return false
  }

  /// Back from the result to the inbox.
  public func dismissResult() {
    result = nil
    resultNumbering = nil
  }

  // MARK: - Internals

  /// The inbox the session names: the loaded account's; while signed in before the load, the
  /// last account's, marked; signed out, the last account's.
  private var destination: (store: InboxStore, marked: Bool)? {
    guard let origin = session.state.origin else { return nil }
    if case .signedIn = session.state, session.accountLoaded, let user = session.user {
      return (InboxStore(store: session.store, origin: origin, account: user.uuid), false)
    }
    guard let last = session.store.lastAccount(for: origin) else { return nil }
    let marked = if case .signedIn = session.state { true } else { false }
    return (InboxStore(store: session.store, origin: origin, account: last), marked)
  }

  private func reload() {
    let store = destination?.store
    if store?.account != shownAccount {
      shownAccount = store?.account
      result = nil
      resultNumbering = nil
      applyError = nil
    }
    let contents = store?.load() ?? InboxStore.Contents()
    files = contents.files
    read = contents.read
  }

  /// After a change to the files: an empty inbox holds no read, and a read of files that are
  /// no longer all waiting is stale.
  private func settleRead(_ contents: inout InboxStore.Contents) {
    guard let read = contents.read else { return }
    if contents.files.isEmpty {
      contents.read = nil
    } else if !Set(read.files).isSubset(of: contents.files.map(\.id)) {
      contents.read?.stale = true
    }
  }

  /// Starts a read, or — for a file arriving during one — asks for one more after it. With no
  /// route only the diver's tap starts one: a read on its own would wait a minute for nothing.
  private func startRead(arrival: Bool, tapped: Bool = false) {
    guard session.accountLoaded, let store = destination?.store,
      let client = try? session.requireClient()
    else { return }
    if readTask != nil {
      if arrival { followUp = true }
      return
    }
    guard tapped || session.connectivity.isRouteAvailable else { return }
    phase = .reading
    applyError = nil
    readTask = Task {
      defer {
        phase = .idle
        readTask = nil
      }
      repeat {
        followUp = false
        guard await readOnce(store, client) else { break }
      } while followUp
    }
  }

  /// One read over every sendable file; false when it never reached the server or there was
  /// nothing to send.
  private func readOnce(_ store: InboxStore, _ client: APIClient) async -> Bool {
    var contents = store.load()
    let sent = contents.files.filter { refusal(for: $0) == nil }
    guard !sent.isEmpty,
      ImportBounds.selectionRefusal(byteSizes: sent.map(\.byteSize)) == nil
    else { return false }
    // A new read supersedes the one on screen before it is sent, so a file arriving while it
    // is in flight finds the inbox uncovered.
    contents.read = nil
    try? store.save(contents)
    reload()

    let ids = sent.map(\.id)
    var answer: InboxRead
    do {
      let preview = try await client.importPreview(
        files: sent.map { ImportFile(file: store.url(for: $0), filename: $0.filename) })
      let numbering = try? await client.diveNumbering()
      answer = InboxRead(files: ids, preview: preview, numbering: numbering)
    } catch let error as APIError {
      switch error {
      case .unreachable, .signedOut, .secretStore:
        return false
      case .http(let status, let message):
        answer = InboxRead(
          files: ids,
          refusal: status >= 500 ? ImportText.readFailed : message ?? ImportText.readFailed)
      case .notAnInstance, .unreadableResponse:
        answer = InboxRead(files: ids, refusal: ImportText.readFailed)
      }
    } catch {
      answer = InboxRead(files: ids, refusal: ImportText.readFailed)
    }
    var now = store.load()
    guard !now.files.isEmpty else { return true }
    answer.stale = !Set(ids).isSubset(of: now.files.map(\.id))
    now.read = answer
    try? store.save(now)
    reload()
    return true
  }

  /// The two 422s that ask for the files to be previewed again: the token expired, or names
  /// other files. The API sends no code to tell them from a refused check-in detail.
  static func isStalePreview(_ message: String?) -> Bool {
    guard let message else { return false }
    return message.contains("Preview the files again") || message.contains("Preview them again")
  }
}

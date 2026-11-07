import Foundation
import Observation

/// The import screen's model over the inbox of the account the session names and the import the
/// server holds for it: files in, the upload, the apply and the discard.
///
/// **An upload is a tap.** It creates a pending import, sealed against more files and blocking
/// every other device, so nothing uploads on an arrival, on the account loading or on a
/// connectivity moment; the tap tries with or without a route.
///
/// **The phone keeps what it sent until the import is seen applied.** A download archive is the
/// only copy of its dives, and a pending import can be discarded on any device or expire. A
/// pending read that does not name the import a file recorded says nothing about it, since
/// another device's apply and a discard or an expiry answer alike, so that import is read itself:
/// `applied` removes its files, a 404 returns them to waiting. A server's answer that is neither
/// leaves everything as it was.
///
/// One upload, apply or discard runs at a time, and a pending read in flight gives way to it.
@MainActor
@Observable
public final class InboxModel {
  public enum Phase: Hashable, Sendable {
    case idle, uploading, importing, discarding
  }

  /// Where a file handed to the app went.
  public enum Intake: Hashable, Sendable {
    /// Into the inbox of `account`; `signedIn` says whether the session can upload it now.
    case kept(account: UUID, signedIn: Bool)
    /// Nowhere, and why, in a sentence for the diver.
    case notKept(String)
  }

  public static let noAccountSentence = "Choose a server and sign in, then share the file again."
  public static let accountLoadingSentence = "Your account is still loading; share the file again."

  /// Every file the phone keeps: the ones waiting to upload, and the ones an import holds.
  public private(set) var files: [InboxFile] = []
  /// The account's pending import as last read, whichever device uploaded it.
  public private(set) var pending: LogbookImportRead?
  public private(set) var phase = Phase.idle
  /// The last apply's answer, shown in place of the review until ``dismissResult()``.
  public private(set) var result: LogbookImportRead?
  /// The result's numbering sentence, where the import tangled the log's numbering.
  public private(set) var resultNumbering: String?
  /// Why the last apply or discard failed.
  public private(set) var applyError: String?
  /// Why the last upload failed, until the next starts.
  public private(set) var uploadError: String?

  /// The files the upload in flight sent.
  private var sending: Set<UUID> = []
  @ObservationIgnored private let session: Session
  /// The upload, the apply or the discard in flight.
  @ObservationIgnored private var workTask: Task<Void, Never>?
  @ObservationIgnored private var readTask: Task<Void, Never>?
  @ObservationIgnored private var shownAccount: UUID?

  public init(session: Session) {
    self.session = session
    // Here rather than on a session change: a cold start offline gets none, and can download.
    // Before the marks too, which read an account's whole records as progress alone.
    DiveComputerStore.adoptAccountRecords(store: session.store)
    reload()
  }

  // MARK: - What the screen shows

  /// Whether the account has loaded in this process, so files can be uploaded and imported.
  public var isAccountLoaded: Bool { session.accountLoaded }

  /// The units the rows print in: the account's, or as last read while it is unknown.
  public var units: UnitSystem {
    if session.accountLoaded { return session.units }
    guard let origin = session.state.origin, let account = destination?.store.account,
      let settings = session.store.formSettings(for: origin, account: account)
    else { return session.units }
    return settings.units
  }

  /// Why one file is left out of every upload, or nil.
  public func refusal(for file: InboxFile) -> String? {
    ImportBounds.fileRefusal(filename: file.filename, byteSize: file.byteSize)
  }

  /// The files no upload has taken.
  public var waiting: [InboxFile] { files.filter { $0.uploadedInto == nil } }

  /// The files an upload sends: every waiting file the bounds do not refuse.
  public var sendable: [InboxFile] { waiting.filter { refusal(for: $0) == nil } }

  /// Why the files cannot go as one import, or nil.
  public var selectionRefusal: String? {
    ImportBounds.selectionRefusal(byteSizes: sendable.map(\.byteSize))
  }

  /// Whether *Upload* can be tapped.
  public var canUpload: Bool {
    session.accountLoaded && phase == .idle && pending == nil && !sendable.isEmpty
      && selectionRefusal == nil
  }

  /// Said beside *Upload* while files wait behind a pending import.
  public var uploadHold: String? {
    pending != nil && !waiting.isEmpty ? ImportText.pendingBlocksUpload : nil
  }

  /// The row of the pending import's `members` a kept file became, and the rows of the files a
  /// zip of it opened into. An import's `part` is the file's place among those it sent, which
  /// the inbox keeps in order and never removes while the import holds them.
  public func members(of file: InboxFile) -> (
    own: ImportMemberReport?, inside: [ImportMemberReport]
  ) {
    guard let pending, file.uploadedInto == pending.uuid,
      let part = files.filter({ $0.uploadedInto == pending.uuid }).firstIndex(of: file),
      let row = pending.members.firstIndex(where: { $0.part == part && $0.container == nil })
    else { return (nil, []) }
    return (pending.members[row], pending.members.filter { $0.container == row })
  }

  /// Where `file` stands: refused by the bounds or by the upload, waiting, being sent, or in an
  /// import.
  public func stage(of file: InboxFile) -> InboxFileStage {
    if file.uploadedInto != nil {
      return members(of: file).own?.refusal.map(InboxFileStage.refused) ?? .uploaded
    }
    if let refusal = refusal(for: file) { return .refused(refusal) }
    return sending.contains(file.id) ? .uploading : .waiting
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
    do {
      try store.save(contents)
    } catch {
      store.discard(added)
      return .notKept("The file could not be kept on this phone: \(error).")
    }
    reload()
    let signedIn = if case .signedIn = session.state { true } else { false }
    return .kept(account: store.account, signedIn: signedIn)
  }

  /// Whether *Remove* asks first: a download archive is the only copy of its dives.
  public func removalNeedsConfirmation(_ file: InboxFile) -> Bool { file.download != nil }

  /// Whether *Remove all* asks first.
  public var removeAllNeedsConfirmation: Bool { waiting.contains { $0.download != nil } }

  /// Replaces download archives waiting to upload with their union, in one save: the union
  /// taken in and recorded and the waiting files' records dropped together, their bytes
  /// discarded only after it, so a failed take leaves them where they were. Acts only while
  /// the inbox is idle and every one of `waiting` is still there and still waiting, as a swap
  /// would otherwise pull a file out from under an upload or the import that holds it; nil
  /// otherwise, for the caller to try again.
  func replaceDownloads(_ waiting: [InboxFile], with union: URL, download: InboxDownload)
    -> Intake?
  {
    guard phase == .idle, let destination else { return nil }
    let store = destination.store
    var contents = store.load()
    let ids = Set(waiting.map(\.id))
    guard ids.isSubset(of: contents.files.filter { $0.uploadedInto == nil }.map(\.id)) else {
      return nil
    }
    let taken: InboxFile
    do {
      taken = try store.take(union, moving: true, marked: destination.marked, download: download)
    } catch {
      return .notKept("The file could not be kept on this phone: \(error).")
    }
    contents.files.removeAll { ids.contains($0.id) }
    contents.files.append(taken)
    do {
      try store.save(contents)
    } catch {
      store.discard([taken])
      return .notKept("The file could not be kept on this phone: \(error).")
    }
    store.discard(waiting)
    reload()
    let signedIn = if case .signedIn = session.state { true } else { false }
    return .kept(account: store.account, signedIn: signedIn)
  }

  /// The account a file handed over now is kept for, and whether it is marked as received
  /// before the account was known; nil where nothing would be kept.
  var keeping: (account: UUID, marked: Bool)? {
    destination.map { ($0.store.account, $0.marked) }
  }

  /// Every download archive on the phone in that inbox with the given mark, an import's among
  /// them: the dives a walk has no need to take again.
  func keptDownloads(marked: Bool) -> [InboxFile] {
    guard let store = destination?.store else { return [] }
    return store.load().files.filter {
      $0.download != nil && $0.receivedBeforeAccountKnown == marked
    }
  }

  /// The download archives of that mark no upload has taken: what a new download may unite
  /// with, an uploaded archive being out of reach under the import that holds it.
  func unitableDownloads(marked: Bool) -> [InboxFile] {
    keptDownloads(marked: marked).filter { $0.uploadedInto == nil }
  }

  /// Whether that inbox holds a full-export archive that is not a download — one the diver
  /// shared — which would make a download's the second archive of one import. Read from each
  /// kept zip's central directory, never from the server.
  var holdsSharedArchive: Bool {
    guard let store = destination?.store else { return false }
    return store.load().files.contains {
      $0.download == nil && ZipReader.isFullExport(store.url(for: $0))
    }
  }

  /// Where a file in that inbox keeps its bytes.
  func url(for file: InboxFile) -> URL? { destination?.store.url(for: file) }

  /// Removes one waiting file; a file an import holds stays until that import settles it.
  public func remove(_ file: InboxFile) {
    guard phase == .idle, file.uploadedInto == nil, let store = destination?.store else { return }
    var contents = store.load()
    contents.files.removeAll { $0.id == file.id }
    try? store.save(contents)
    store.discard([file])
    reload()
  }

  /// Removes every waiting file.
  public func removeAll() {
    guard phase == .idle, let store = destination?.store else { return }
    var contents = store.load()
    let removed = contents.files.filter { $0.uploadedInto == nil }
    contents.files.removeAll { $0.uploadedInto == nil }
    try? store.save(contents)
    store.discard(removed)
    reload()
  }

  /// The session changed — signed in or out, or the account loaded. A load moves the files
  /// received before it into the loaded account's inbox, and removes the dive computers'
  /// progress written before it for any other account; a session that ended before one leaves
  /// them where they are.
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
          // A computer's progress written before the load stays only with the account it was
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
  }

  /// Waits for the upload, the apply or the discard in flight, and the pending read after it.
  public func settled() async {
    while let task = workTask ?? readTask {
      await task.value
    }
  }

  // MARK: - The upload

  /// The diver's *Upload*: every waiting file the bounds admit, in one request. On the server's
  /// 201 each records the import and the answer is the pending import; on anything else the
  /// files stay waiting, and a 409 reads the pending import it names.
  public func upload() {
    guard canUpload, let store = destination?.store, let client = try? session.requireClient()
    else { return }
    let sent = store.load().files.filter { $0.uploadedInto == nil && refusal(for: $0) == nil }
    stopReading()
    phase = .uploading
    sending = Set(sent.map(\.id))
    uploadError = nil
    applyError = nil
    workTask = Task {
      let reread = await send(sent, store, client)
      sending = []
      finishWork(reread: reread)
    }
  }

  /// The upload itself; true when the pending import is to be read.
  private func send(_ sent: [InboxFile], _ store: InboxStore, _ client: APIClient) async -> Bool {
    do {
      let held = try await client.uploadImport(
        files: sent.map { ImportFile(file: store.url(for: $0), filename: $0.filename) })
      let ids = Set(sent.map(\.id))
      var contents = store.load()
      for index in contents.files.indices where ids.contains(contents.files[index].id) {
        contents.files[index].uploadedInto = held.uuid
      }
      try? store.save(contents)
      reload()
      if shownAccount == store.account { pending = held }
    } catch let error as APIError {
      switch error {
      case .http(let status, let message):
        uploadError = status >= 500 ? ImportText.uploadFailed : message ?? ImportText.uploadFailed
        return status == 409
      case .unreachable: uploadError = ImportText.unreachable
      case .secretStore: uploadError = error.message
      case .notAnInstance, .unreadableResponse: uploadError = ImportText.uploadFailed
      case .signedOut: break
      }
    } catch is CancellationError {
      // The app left this server; its files wait for the next upload there.
    } catch {
      uploadError = ImportText.uploadFailed
    }
    return false
  }

  // MARK: - The pending import

  /// The Import screen appearing: reads the pending import and settles the imports the files
  /// recorded. Never without a route, when it would wait a minute for nothing and hold nothing up.
  public func readPending() {
    guard phase == .idle, session.connectivity.isRouteAvailable else { return }
    startReading()
  }

  private func startReading() {
    guard readTask == nil, session.accountLoaded, let store = destination?.store,
      let client = try? session.requireClient()
    else { return }
    readTask = Task {
      await readAndSettle(store, client)
      if !Task.isCancelled { readTask = nil }
    }
  }

  /// A cancelled read's answers are dropped, however late they arrive.
  private func stopReading() {
    readTask?.cancel()
    readTask = nil
  }

  private func readAndSettle(_ store: InboxStore, _ client: APIClient) async {
    let held: LogbookImportRead?
    do {
      held = try await client.pendingImport()
    } catch APIError.http(404, _) {
      held = nil
    } catch {
      return
    }
    guard !Task.isCancelled else { return }
    pending = held
    var recorded = Set(store.load().files.compactMap(\.uploadedInto))
    if let held { recorded.remove(held.uuid) }
    for uuid in recorded {
      do {
        let found = try await client.logbookImport(uuid)
        guard !Task.isCancelled else { return }
        if found.isApplied { seenApplied(found, store) }
      } catch APIError.http(404, _) {
        guard !Task.isCancelled else { return }
        returnToWaiting(uuid, store)
      } catch {
        return
      }
    }
  }

  /// An applied import's files leave the inbox, whichever device applied it. A download archive
  /// whose own row the upload refused is the only copy of its dives, so it returns to waiting,
  /// to go up alone; every other file goes, another copy of a shared file existing wherever it
  /// was shared from.
  private func seenApplied(_ read: LogbookImportRead, _ store: InboxStore) {
    var contents = store.load()
    let sent = contents.files.filter { $0.uploadedInto == read.uuid }
    let kept = Set(
      sent.enumerated().filter { part, file in
        file.download != nil
          && read.members.contains { $0.part == part && $0.container == nil && $0.refusal != nil }
      }.map(\.element.id))
    contents.files.removeAll { $0.uploadedInto == read.uuid && !kept.contains($0.id) }
    for index in contents.files.indices where kept.contains(contents.files[index].id) {
      contents.files[index].uploadedInto = nil
    }
    guard (try? store.save(contents)) != nil else { return }
    store.discard(sent.filter { !kept.contains($0.id) })
    reload()
    if let stores = AccountStores.current(session) {
      OutboxHub.hub(for: stores.directory).listsChanged()
    }
  }

  /// The import is gone unapplied: its files wait to go up again.
  private func returnToWaiting(_ uuid: UUID, _ store: InboxStore) {
    var contents = store.load()
    for index in contents.files.indices where contents.files[index].uploadedInto == uuid {
      contents.files[index].uploadedInto = nil
    }
    try? store.save(contents)
    reload()
  }

  // MARK: - Apply and discard

  /// The diver's *Import*: writes the pending import as reviewed, with the check-in choices.
  public func apply(_ choices: ImportCheckInChoices) {
    guard phase == .idle, session.accountLoaded, let pending, let store = destination?.store,
      let client = try? session.requireClient()
    else { return }
    stopReading()
    phase = .importing
    applyError = nil
    workTask = Task {
      finishWork(reread: await perform(choices, pending, store, client))
    }
  }

  /// The apply itself; true when the pending import is to be read.
  private func perform(
    _ choices: ImportCheckInChoices, _ held: LogbookImportRead, _ store: InboxStore,
    _ client: APIClient
  ) async -> Bool {
    do {
      let applied = try await client.applyImport(held.uuid, choices.apply(for: held))
      let after = try? await client.diveNumbering()
      seenApplied(applied, store)
      if shownAccount == store.account {
        pending = nil
        result = applied
        resultNumbering = ImportText.numberingSuggestion(
          before: applied.numbering, after: after, dives: applied.dives)
      }
      return true
    } catch {
      return refused(error)
    }
  }

  /// The diver's *Discard*: deletes the pending import, whichever device uploaded it, and the
  /// files it held here wait to go up again.
  public func discard() {
    guard phase == .idle, session.accountLoaded, let pending, let store = destination?.store,
      let client = try? session.requireClient()
    else { return }
    stopReading()
    phase = .discarding
    applyError = nil
    workTask = Task {
      do {
        try await client.deleteImport(pending.uuid, status: "pending")
        returnToWaiting(pending.uuid, store)
        if shownAccount == store.account { self.pending = nil }
        finishWork(reread: true)
      } catch {
        finishWork(reread: refused(error))
      }
    }
  }

  /// Says why an apply or a discard failed; true when another device may have applied or
  /// discarded the import, which the pending read then finds out.
  private func refused(_ error: any Error) -> Bool {
    switch error {
    case APIError.http(let status, let message):
      applyError = message ?? ImportText.applyFailed
      return status == 404 || status == 409
    case let error as APIError:
      applyError = error.message
    case is CancellationError:
      // The app left this server mid-request; the import stands, to finish there.
      break
    default:
      applyError = ImportText.applyFailed
    }
    return false
  }

  private func finishWork(reread: Bool) {
    phase = .idle
    workTask = nil
    if reread { startReading() }
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
      stopReading()
      pending = nil
      result = nil
      resultNumbering = nil
      applyError = nil
      uploadError = nil
    }
    files = store?.load().files ?? []
  }
}

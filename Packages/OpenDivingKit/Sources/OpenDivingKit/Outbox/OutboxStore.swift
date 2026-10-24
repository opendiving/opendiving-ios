import Foundation

/// One account's outbox on disk, in the account's directory: `Outbox/items/` with a file per
/// queued write, `Outbox/resolutions/` holding the `local → server` table a file per landed
/// create, and `Outbox/notices/` for what the pending screen says once about a write that is
/// done. Sign-out leaves it; ``ServerStateStore/forget(_:)`` removes it with the server's.
public struct OutboxStore: Sendable {
  /// How a create came back: named by the server, or never to be named.
  struct Resolution: Codable, Hashable, Sendable {
    let local: UUID
    /// The server's uuid; nil when the record landed in a form this build could not read, or
    /// was deleted before the retry.
    let server: UUID?
    /// Why it cannot be resolved, for the items that named it.
    let sentence: String?
  }

  /// The account's name, kept so that a write moved away from it can say whom it was for.
  struct AccountLabel: Codable, Hashable, Sendable {
    let name: String
    let username: String
  }

  public let account: UUID
  let root: URL

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    self.account = account
    root = store.directory(for: origin, account: account)
      .appendingPathComponent("Outbox", isDirectory: true)
  }

  /// The outbox of every account this server has a directory for.
  public static func all(store: ServerStateStore, origin: ServerOrigin) -> [OutboxStore] {
    let accounts = store.directory(for: origin).appendingPathComponent(
      "Accounts", isDirectory: true)
    let names = (try? FileManager.default.contentsOfDirectory(atPath: accounts.path)) ?? []
    return names.compactMap(UUID.init(uuidString:)).map {
      OutboxStore(store: store, origin: origin, account: $0)
    }
  }

  /// What every account's stores on this server hold that has not reached it, which
  /// `forget` would discard.
  public static func summary(store: ServerStateStore, origin: ServerOrigin) -> OutboxSummary {
    var summary = OutboxSummary()
    for outbox in all(store: store, origin: origin) {
      for item in outbox.items() {
        if item.operation.kind == .dive { summary.dives += 1 } else { summary.others += 1 }
      }
      summary.unreadable += outbox.unreadableItems().count
      let drafts = outbox.root.deletingLastPathComponent()
        .appendingPathComponent("Drafts", isDirectory: true)
      summary.editDrafts +=
        ((try? FileManager.default.contentsOfDirectory(atPath: drafts.path)) ?? [])
        .filter { $0.hasSuffix(".json") }.count
      summary.unreadable +=
        InboxStore(store: store, origin: origin, account: outbox.account).unreadableCount
    }
    return summary
  }

  // MARK: - Items

  /// The readable items in queue order. One found in flight is pending again.
  public func items() -> [OutboxItem] {
    itemFolder.load().values.map { entry in
      var item = entry.value
      if item.state == .inFlight { item.state = .pending(lastAnswer: .unreachable) }
      return item
    }
    .sorted { ($0.sequence, $0.queuedAt) < ($1.sequence, $1.queuedAt) }
  }

  /// The item files this build cannot read, by name: listed as saved by another version of
  /// the app, never sent and never overwritten.
  public func unreadableItems() -> [String] {
    itemFolder.load().unreadable
  }

  func save(_ item: OutboxItem) throws {
    try itemFolder.write(item, name: KeptFolder<OutboxItem>.name(for: item.id))
  }

  func remove(_ id: UUID) {
    itemFolder.remove(KeptFolder<OutboxItem>.name(for: id))
  }

  /// Removes an item file this build could not read; the diver's *Discard*.
  public func removeUnreadable(_ name: String) {
    guard itemFolder.read(name) == nil else { return }
    itemFolder.remove(name)
  }

  /// The order the next item takes.
  func nextSequence() -> Int {
    (items().map(\.sequence).max() ?? 0) + 1
  }

  // MARK: - Resolutions

  func resolutions() -> [UUID: Resolution] {
    Dictionary(
      resolutionFolder.load().values.map { ($0.value.local, $0.value) },
      uniquingKeysWith: { a, _ in a })
  }

  /// `ref` as the server names it, once its create has landed.
  func resolved(_ ref: RecordRef) -> RecordRef {
    guard case .local(let local) = ref, let server = resolutions()[local]?.server else {
      return ref
    }
    return .server(server)
  }

  /// Removes the resolutions nothing on the phone names any more: no queued item and no edit
  /// draft holds the local ref, and a day has passed for a form still open on it. Every later
  /// read of the table decodes what is left.
  func pruneResolutions(keepingFor age: TimeInterval = 24 * 60 * 60) {
    let manager = FileManager.default
    let folder = resolutionFolder.url
    guard let names = try? manager.contentsOfDirectory(atPath: folder.path), !names.isEmpty
    else { return }
    let drafts = root.deletingLastPathComponent().appendingPathComponent(
      "Drafts", isDirectory: true)
    var named = Data()
    for directory in [root.appendingPathComponent("items", isDirectory: true), drafts] {
      for name in (try? manager.contentsOfDirectory(atPath: directory.path)) ?? [] {
        named += (try? Data(contentsOf: directory.appendingPathComponent(name))) ?? Data()
      }
    }
    let cutoff = Date().addingTimeInterval(-age)
    for name in names where name.hasSuffix(".json") {
      let file = folder.appendingPathComponent(name, isDirectory: false)
      let recorded = (try? manager.attributesOfItem(atPath: file.path)[.modificationDate]) as? Date
      guard let recorded, recorded < cutoff else { continue }
      let ref = Data((RecordRef.localPrefix + name.dropLast(".json".count)).utf8)
      if named.range(of: ref) == nil { try? manager.removeItem(at: file) }
    }
  }

  func record(_ resolution: Resolution) throws {
    try resolutionFolder.write(resolution, name: KeptFolder<Resolution>.name(for: resolution.local))
  }

  // MARK: - Notices

  public func notices() -> [OutboxNotice] {
    noticeFolder.load().values.map(\.value).sorted { $0.at < $1.at }
  }

  func add(_ notice: OutboxNotice) throws {
    try noticeFolder.write(notice, name: KeptFolder<OutboxNotice>.name(for: notice.id))
  }

  func removeNotice(_ id: UUID) {
    noticeFolder.remove(KeptFolder<OutboxNotice>.name(for: id))
  }

  // MARK: - The account's name

  func accountLabel() -> AccountLabel? {
    labelFolder.read("account.json")
  }

  func rememberAccountLabel(_ user: UserRead) {
    let label = AccountLabel(name: user.name, username: user.username)
    guard accountLabel() != label else { return }
    try? labelFolder.write(label, name: "account.json")
  }

  // MARK: - Paths

  private var itemFolder: KeptFolder<OutboxItem> {
    KeptFolder(url: root.appendingPathComponent("items", isDirectory: true))
  }

  private var resolutionFolder: KeptFolder<Resolution> {
    KeptFolder(url: root.appendingPathComponent("resolutions", isDirectory: true))
  }

  private var noticeFolder: KeptFolder<OutboxNotice> {
    KeptFolder(url: root.appendingPathComponent("notices", isDirectory: true))
  }

  private var labelFolder: KeptFolder<AccountLabel> { KeptFolder(url: root) }
}

/// A sentence the pending screen shows once about a write that is done but did not land as
/// sent — saved but unreadable, or gone — until the diver dismisses it.
public struct OutboxNotice: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let at: Date
  public let kind: OutboxRecordKind
  public let sentence: String

  init(kind: OutboxRecordKind, sentence: String, at: Date = Date()) {
    id = UUID()
    self.at = at
    self.kind = kind
    self.sentence = sentence
  }
}

/// What a server's stores hold that has not reached it.
public struct OutboxSummary: Hashable, Sendable {
  /// Dives created, logged from a draft or edited, waiting.
  public var dives = 0
  /// Every other write waiting: records, gear sets, drafts.
  public var others = 0
  /// Edits of dives in progress, kept on the phone alone.
  public var editDrafts = 0
  /// Writes and files' records saved by another version of the app.
  public var unreadable = 0

  public init() {}

  public var isEmpty: Bool { self == OutboxSummary() }
}

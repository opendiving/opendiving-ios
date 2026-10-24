import Foundation

/// One account's inbox: the files waiting to be imported, kept under `Inbox/files/` by names
/// of their own, and `inbox.json` holding a record per file and the last read.
///
/// It lives in the account's directory, so sign-out leaves it and
/// ``ServerStateStore/forget(_:)`` removes it with the server's.
public struct InboxStore: Sendable {
  /// What `inbox.json` holds.
  public struct Contents: Codable, Hashable, Sendable {
    public var files: [InboxFile]
    public var read: InboxRead?

    public init(files: [InboxFile] = [], read: InboxRead? = nil) {
      self.files = files
      self.read = read
    }
  }

  public let account: UUID
  let root: URL

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    self.account = account
    root = store.directory(for: origin, account: account)
      .appendingPathComponent("Inbox", isDirectory: true)
  }

  /// The inbox of every account this server has a directory for.
  static func all(store: ServerStateStore, origin: ServerOrigin) -> [InboxStore] {
    let accounts = store.directory(for: origin).appendingPathComponent(
      "Accounts", isDirectory: true)
    let names = (try? FileManager.default.contentsOfDirectory(atPath: accounts.path)) ?? []
    return names.compactMap(UUID.init(uuidString:)).map {
      InboxStore(store: store, origin: origin, account: $0)
    }
  }

  public func load() -> Contents {
    guard let data = try? Data(contentsOf: recordFile) else { return Contents() }
    return (try? APICoding.decoder().decode(Contents.self, from: data)) ?? Contents()
  }

  public func save(_ contents: Contents) throws {
    try FileManager.default.createDirectory(at: filesFolder, withIntermediateDirectories: true)
    try APICoding.encoder().encode(contents).write(to: recordFile, options: .atomic)
  }

  /// Where a waiting file's bytes are.
  public func url(for file: InboxFile) -> URL {
    filesFolder.appendingPathComponent(file.id.uuidString.lowercased(), isDirectory: false)
  }

  /// Takes `source` into the inbox under a name of its own and returns its record, which the
  /// caller saves. `moving` takes the file itself — the copy iOS made for the app — and
  /// otherwise copies it, leaving the original where another app keeps it.
  func take(_ source: URL, moving: Bool, marked: Bool) throws -> InboxFile {
    try FileManager.default.createDirectory(at: filesFolder, withIntermediateDirectories: true)
    let size =
      (try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.intValue
      ?? 0
    let file = InboxFile(
      filename: source.lastPathComponent, byteSize: size, receivedBeforeAccountKnown: marked)
    if moving {
      try FileManager.default.moveItem(at: source, to: url(for: file))
    } else {
      try FileManager.default.copyItem(at: source, to: url(for: file))
    }
    return file
  }

  /// Removes the bytes of files whose records are gone; a missing file is no error.
  func discard(_ files: [InboxFile]) {
    for file in files { try? FileManager.default.removeItem(at: url(for: file)) }
  }

  /// Moves the files marked as received before the account was known out of `other` and into
  /// this inbox, unmarked: copied and recorded here before they leave there, so an
  /// interruption leaves a file twice rather than nowhere. Returns how many moved.
  @discardableResult
  func takeMarked(from other: InboxStore) throws -> Int {
    var theirs = other.load()
    let marked = theirs.files.filter(\.receivedBeforeAccountKnown)
    guard !marked.isEmpty else { return 0 }
    var mine = load()
    try FileManager.default.createDirectory(at: filesFolder, withIntermediateDirectories: true)
    for file in marked {
      var moved = file
      moved.receivedBeforeAccountKnown = false
      try FileManager.default.copyItem(at: other.url(for: file), to: url(for: moved))
      mine.files.append(moved)
    }
    if mine.read != nil { mine.read?.stale = true }
    try save(mine)
    theirs.files.removeAll(where: \.receivedBeforeAccountKnown)
    if theirs.read != nil { theirs.read?.stale = true }
    try other.save(theirs)
    other.discard(marked)
    return marked.count
  }

  /// Clears every mark: the account the files were received for is the one they stay with.
  func clearMarks() throws {
    var contents = load()
    guard contents.files.contains(where: \.receivedBeforeAccountKnown) else { return }
    for index in contents.files.indices { contents.files[index].receivedBeforeAccountKnown = false }
    try save(contents)
  }

  private var recordFile: URL { root.appendingPathComponent("inbox.json", isDirectory: false) }
  private var filesFolder: URL { root.appendingPathComponent("files", isDirectory: true) }
}

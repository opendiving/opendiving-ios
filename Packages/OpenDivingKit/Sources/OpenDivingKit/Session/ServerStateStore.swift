import Foundation

/// Everything the phone keeps about one server, as one thing: the refresh token in the
/// ``SecretStore``, the remembered account, and a directory under Application Support that
/// other features write into — the check-in sheet among them. ``forget(_:)`` is the only call
/// that removes all three, so no feature needs a forget path of its own.
public struct ServerStateStore: Sendable {
  private let root: URL
  private let secrets: any SecretStore
  private let activeOrigin: any ActiveOriginStore

  /// `root` is the app's Application Support directory, or a temporary one in a test.
  public init(root: URL, secrets: any SecretStore, activeOrigin: any ActiveOriginStore) {
    self.root = root
    self.secrets = secrets
    self.activeOrigin = activeOrigin
  }

  /// The server's own directory. Not created here; a feature that writes creates it.
  public func directory(for origin: ServerOrigin) -> URL {
    root.appendingPathComponent("Servers", isDirectory: true)
      .appendingPathComponent(origin.slug, isDirectory: true)
  }

  /// The account last read from the server, kept beside the directory rather than in it so
  /// that ending a session can drop it and leave the directory alone.
  func userFile(for origin: ServerOrigin) -> URL {
    root.appendingPathComponent("Accounts", isDirectory: true)
      .appendingPathComponent(origin.slug + ".json", isDirectory: false)
  }

  public func rememberedUser(for origin: ServerOrigin) -> UserRead? {
    guard let data = try? Data(contentsOf: userFile(for: origin)) else { return nil }
    return try? APICoding.decoder().decode(UserRead.self, from: data)
  }

  func remember(_ user: UserRead, for origin: ServerOrigin) throws {
    let file = userFile(for: origin)
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try APICoding.encoder().encode(user).write(to: file, options: .atomic)
  }

  /// A session ended, by sign-out or by the server refusing it: the token and the account go,
  /// the directory and the active-origin pointer stay.
  func endSession(for origin: ServerOrigin) throws {
    try secrets.removeSecret(for: origin.description)
    try removeIfPresent(userFile(for: origin))
  }

  /// Removes the token, the remembered account and the directory, and clears the
  /// active-origin pointer when it names this server. Needs no server, so a server that is
  /// gone can still be forgotten.
  public func forget(_ origin: ServerOrigin) throws {
    try endSession(for: origin)
    try removeIfPresent(directory(for: origin))
    if activeOrigin.load() == origin {
      activeOrigin.save(nil)
    }
  }

  /// Whether the phone holds anything for this server: a token, a remembered account or a
  /// directory.
  public func hasState(_ origin: ServerOrigin) -> Bool {
    let hasSecret = ((try? secrets.secret(for: origin.description)) ?? nil) != nil
    return hasSecret || exists(userFile(for: origin)) || exists(directory(for: origin))
  }

  func hasRefreshToken(_ origin: ServerOrigin) -> Bool {
    ((try? secrets.secret(for: origin.description)) ?? nil) != nil
  }

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  private func removeIfPresent(_ url: URL) throws {
    guard exists(url) else { return }
    try FileManager.default.removeItem(at: url)
  }
}

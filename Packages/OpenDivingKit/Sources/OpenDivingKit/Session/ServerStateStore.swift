import Foundation

/// Everything the phone keeps about one server, as one thing: the refresh token in the
/// ``SecretStore``, the remembered account, and a directory under Application Support that
/// other features write into — the check-in sheet among them. ``forget(_:)`` is the only call
/// that removes all three, so no feature needs a forget path of its own.
///
/// Inside the server's directory each account the phone has loaded there has one of its own,
/// ``directory(for:account:)``, for what belongs to that account rather than to the server —
/// a sign-in to the same server can be another account. Beside them a pointer names the
/// account last loaded, ``lastAccount(for:)``, which outlives a sign-out so that a signed-out
/// phone still knows whose stores to show.
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

  /// An account's own directory inside the server's: `Servers/<slug>/Accounts/<user uuid>/`.
  /// Not created here; a feature that writes creates it. ``forget(_:)`` removes it with the
  /// server's; ending a session leaves it.
  public func directory(for origin: ServerOrigin, account: UUID) -> URL {
    directory(for: origin).appendingPathComponent("Accounts", isDirectory: true)
      .appendingPathComponent(account.uuidString.lowercased(), isDirectory: true)
  }

  /// The account `loadAccount()` last read from this server, signed in or not since; nil
  /// before one has loaded.
  public func lastAccount(for origin: ServerOrigin) -> UUID? {
    guard let data = try? Data(contentsOf: lastAccountFile(for: origin)) else { return nil }
    return (try? APICoding.decoder().decode(LastAccount.self, from: data))?.userUuid
  }

  /// What the dive form needs of `account` when no `GET /user` can be read — signed out, or
  /// offline before the account loads: its units and its hidden fields, as last read.
  public func formSettings(for origin: ServerOrigin, account: UUID) -> AccountFormSettings? {
    guard let data = try? Data(contentsOf: formSettingsFile(for: origin, account: account))
    else { return nil }
    return try? APICoding.decoder().decode(AccountFormSettings.self, from: data)
  }

  /// Points the server's last-account pointer at `user` and keeps its form settings in its
  /// directory. Written when the account has been read, never at sign-in, whose answer names
  /// no account.
  func rememberLastAccount(_ user: UserRead, for origin: ServerOrigin) throws {
    try write(
      AccountFormSettings(units: user.units, diveFormHiddenFields: user.diveFormHiddenFields),
      to: formSettingsFile(for: origin, account: user.uuid))
    try write(LastAccount(userUuid: user.uuid), to: lastAccountFile(for: origin))
  }

  private func lastAccountFile(for origin: ServerOrigin) -> URL {
    directory(for: origin).appendingPathComponent("last-account.json", isDirectory: false)
  }

  private func formSettingsFile(for origin: ServerOrigin, account: UUID) -> URL {
    directory(for: origin, account: account)
      .appendingPathComponent("form-settings.json", isDirectory: false)
  }

  private struct LastAccount: Codable {
    let userUuid: UUID
  }

  private func write(_ value: some Encodable, to file: URL) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try APICoding.encoder().encode(value).write(to: file, options: .atomic)
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
    try write(user, to: userFile(for: origin))
  }

  /// A session ended, by sign-out or by the server refusing it: the token and the account go;
  /// the directory, the last-account pointer and the active-origin pointer stay.
  func endSession(for origin: ServerOrigin) throws {
    try secrets.removeSecret(for: origin.description)
    try removeIfPresent(userFile(for: origin))
  }

  /// Removes the token, the remembered account and the directory — every account's directory
  /// and the last-account pointer with it — and clears the active-origin pointer when it names
  /// this server. Needs no server, so a server that is
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
    hasRefreshToken(origin) || exists(userFile(for: origin)) || exists(directory(for: origin))
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

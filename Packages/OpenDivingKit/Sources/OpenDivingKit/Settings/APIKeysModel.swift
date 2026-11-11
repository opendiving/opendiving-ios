import Foundation
import Observation

/// *Authentication*'s API keys, for a diver's own tools: each listed with what it may do and
/// when it was made, last used and expires, created from a form with the web's fields and
/// defaults, and revoked after a confirmation. Direct calls, online only.
///
/// A new key's secret is held here and nowhere else — no file, no log, no description of this
/// model or of the answer that carried it — and is gone at ``done()``, which the screen also
/// calls as the diver leaves it. The server keeps only a fingerprint, so nothing shows it again.
@MainActor
@Observable
public final class APIKeysModel {
  /// The longest name the server stores, the passkey's own bound.
  nonisolated public static let nameMaxLength = PasskeysModel.nameMaxLength

  public let list: OptionalList<[APIKeyRead]>

  /// The create form is open.
  public private(set) var isCreating = false
  public var name = ""
  /// Read only by default, so writing is a choice somebody made.
  public var scope = APIKeyScope.read
  /// A year by default, so *Never* is a choice somebody made.
  public var lifetime = APIKeyLifetime.oneYear
  /// What is wrong with ``name``, once a create has been tried with it.
  public private(set) var nameError: String?
  public private(set) var isSubmitting = false
  /// Why the last create made no key: the API's sentence, the cap's and the rate limit's
  /// included.
  public private(set) var createFailure: String?

  /// The key just made, with its secret, until ``done()``.
  public private(set) var created: APIKeyCreated?

  /// The key waiting for the diver to confirm its revocation.
  public var confirmingRevoke: APIKeyRead?
  public private(set) var revoking: UUID?
  /// Why the last revocation failed.
  public private(set) var revokeFailure: String?

  /// When the screen opened, which a row's *Expired* is judged against.
  public let now: Date

  @ObservationIgnored private let session: Session

  public init(session: Session, now: Date = Date()) {
    self.session = session
    self.now = now
    list = OptionalList(session: session) { try await $0.apiKeys() }
  }

  /// A key can be made once the list has been read, so the new row has a list to join.
  public var canCreate: Bool { list.value != nil && !isCreating }

  public func startCreating() {
    guard canCreate else { return }
    isCreating = true
  }

  /// Closes the form, back to its defaults.
  public func cancelCreating() {
    guard !isSubmitting else { return }
    isCreating = false
    name = ""
    scope = .read
    lifetime = .oneYear
    nameError = nil
    createFailure = nil
  }

  public func create() async {
    guard isCreating, !isSubmitting else { return }
    let name = name.trimmedOfWhitespace
    nameError = Self.nameProblem(name)
    createFailure = nil
    guard nameError == nil else { return }
    isSubmitting = true
    let made: APIKeyCreated
    do {
      made = try await session.routedClient().createAPIKey(
        APIKeyCreate(name: name, scope: scope, lifetime: lifetime))
    } catch {
      isSubmitting = false
      createFailure = APIError(error).message
      return
    }
    isSubmitting = false
    // Added from the answer rather than read again: no later read carries the secret, and the
    // list is oldest first.
    list.update { $0 + [made.key] }
    created = made
    cancelCreating()
  }

  /// The secret to show on `key`'s row: only the key just made has one.
  public func secret(for key: APIKeyRead) -> String? {
    created?.key.uuid == key.uuid ? created?.secret : nil
  }

  /// Lets the secret go.
  public func done() {
    created = nil
  }

  /// Revokes `key`, the one the confirmation named. It is handed in rather than read from
  /// ``confirmingRevoke``, which the dialog clears as it closes, before this runs.
  public func confirmRevoke(_ key: APIKeyRead) async {
    guard revoking == nil else { return }
    confirmingRevoke = nil
    revokeFailure = nil
    revoking = key.uuid
    defer { revoking = nil }
    do {
      try await session.routedClient().revokeAPIKey(key.uuid)
    } catch {
      revokeFailure = APIError(error).message
      return
    }
    if created?.key.uuid == key.uuid { created = nil }
    await list.load()
  }

  nonisolated static func nameProblem(_ name: String) -> String? {
    if name.isEmpty { return "Give the key a name." }
    if name.unicodeScalars.count > nameMaxLength { return "At most \(nameMaxLength) characters." }
    return nil
  }

  // MARK: - What the block says

  public static let description =
    "Let a script or a tool of your own use your account through the API. A key's secret is"
    + " shown once, when you create it. Signing other devices out leaves keys working \u{2014}"
    + " each one is revoked here, on its own."
  public static let empty =
    "No API keys yet. Your browser and the OpenDiving app need none; a key is for a tool of your"
    + " own."
  public static let loadFailed = "Couldn't load your API keys."
  public static let createButton = "Create API key"
  public static let namePlaceholder = "laptop"
  public static let expired = "Expired"
  public static let secretLabel = "New API key"
  public static let secretCopied = "API key copied"
  public static let secretNote =
    "Copy it now: it can't be shown again, because only a fingerprint of it is kept. Send it as"
    + " Authorization: Bearer <key>."
  public static let revokeTitle = "Revoke API key"
  public static let revokeButton = "Revoke"

  public static func revokeMessage(_ key: APIKeyRead) -> String {
    "\u{201C}\(key.name)\u{201D} stops working on its very next request, and can't be brought"
      + " back - whatever uses it will need a new key."
  }

  nonisolated public static func label(_ scope: APIKeyScope) -> String {
    switch scope {
    case .read: "Read only"
    case .write: "Read and write"
    }
  }

  nonisolated public static func label(_ lifetime: APIKeyLifetime) -> String {
    switch lifetime {
    case .thirtyDays: "30 days"
    case .ninetyDays: "90 days"
    case .oneYear: "1 year"
    case .never: "Never"
    }
  }

  /// `Created Oct 1, 2026 · Never used · Expires Oct 1, 2027`, by the day alone.
  nonisolated public static func details(
    _ key: APIKeyRead, now: Date, in timeZone: TimeZone = .current
  ) -> String {
    let created = "Created " + PasskeysModel.day(key.createdAt, timeZone)
    let used = key.lastUsedAt.map { "Last used " + PasskeysModel.day($0, timeZone) } ?? "Never used"
    let expires =
      key.expiresAt.map {
        (key.isExpired(at: now) ? "Expired " : "Expires ") + PasskeysModel.day($0, timeZone)
      } ?? "No expiry"
    return [created, used, expires].joined(separator: " · ")
  }
}

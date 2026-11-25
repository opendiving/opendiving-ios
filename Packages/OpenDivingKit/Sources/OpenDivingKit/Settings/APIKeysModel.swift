import Foundation
import Observation

/// *Authentication*'s API keys, for a diver's own tools: each listed with what it may do and
/// when it was made, last used and expires, created from a form with the web's fields and
/// defaults, and revoked after a confirmation. Direct calls, online only; the list is kept for
/// the next visit, its rows alone.
///
/// A key is made as the web makes one, with the permissions picked from the server's own list.
/// A legacy *Read only* or *Read and write* key is still listed and revoked here, and no longer
/// made.
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
  /// Every permission a new key can be given, read as the form opens.
  public let permissions: OptionalList<[String]>

  /// The create form is open.
  public private(set) var isCreating = false
  public var name = ""
  /// Dive reads alone by default, so anything more is a choice somebody made.
  public private(set) var scopes = defaultScopes
  /// A year by default, so *Never* is a choice somebody made.
  public var lifetime = APIKeyLifetime.oneYear
  /// What is wrong with ``name``, once a create has been tried with it.
  public private(set) var nameError: String?
  /// Set once a create has been tried with no permission picked.
  public private(set) var scopesError: String?
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
  /// The key ``revokeFailure`` is about.
  private var revokeFailed: UUID?

  /// What a row's *Expired* is judged against: read as the rows are drawn, so the list's next
  /// read, the one on coming back to the app among them, judges a key an hour long afresh.
  public var now: Date { clock() }

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let clock: @Sendable () -> Date

  public init(session: Session, clock: @escaping @Sendable () -> Date = { Date() }) {
    self.session = session
    self.clock = clock
    list = OptionalList(session: session, kept: .apiKeys) { try await $0.apiKeys() }
    permissions = OptionalList(session: session) { try await $0.apiKeyPermissions() }
  }

  /// A key can be made once the list has been read, so the new row has a list to join.
  public var canCreate: Bool { list.value != nil && !isCreating }

  public func startCreating() {
    guard canCreate else { return }
    isCreating = true
  }

  /// A key is sent once the server has said which permissions it can carry.
  public var canSubmit: Bool { permissions.value != nil && !isSubmitting }

  public func isGranted(_ scope: String) -> Bool { scopes.contains(scope) }

  public func grant(_ scope: String, _ granted: Bool) {
    if granted { scopes.insert(scope) } else { scopes.remove(scope) }
    scopesError = nil
  }

  /// Every read the server offers but check-in's.
  public func grantReadsOnly() {
    scopes = Set(PermissionGroup.reads(permissions.value ?? []))
    scopesError = nil
  }

  public func grantAll() {
    scopes = Set(permissions.value ?? [])
    scopesError = nil
  }

  /// `3 of 45 selected`.
  public var grantedCount: String {
    let offered = permissions.value ?? []
    return "\(offered.filter(scopes.contains).count) of \(offered.count) selected"
  }

  /// Closes the form, back to its defaults.
  public func cancelCreating() {
    guard !isSubmitting else { return }
    isCreating = false
    name = ""
    scopes = Self.defaultScopes
    lifetime = .oneYear
    nameError = nil
    scopesError = nil
    createFailure = nil
  }

  public func create() async {
    guard isCreating, let offered = permissions.value, !isSubmitting else { return }
    let name = name.trimmedOfWhitespace
    // Sent in the server's order, and only what it offers.
    let granted = offered.filter(scopes.contains)
    nameError = Self.nameProblem(name)
    scopesError = granted.isEmpty ? Self.noPermission : nil
    createFailure = nil
    guard nameError == nil, scopesError == nil else { return }
    isSubmitting = true
    let made: APIKeyCreated
    do {
      made = try await session.routedClient().createAPIKey(
        APIKeyCreate(name: name, scope: .scoped, scopes: granted, lifetime: lifetime))
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
    revokeFailed = nil
    revoking = key.uuid
    defer { revoking = nil }
    do {
      try await session.routedClient().revokeAPIKey(key.uuid)
    } catch {
      revokeFailure = APIError(error).message
      revokeFailed = key.uuid
      return
    }
    if created?.key.uuid == key.uuid { created = nil }
    await list.load()
  }

  /// Why the last revocation failed, where it was `key`'s: a key's own page shows no other's.
  public func revokeFailure(for key: APIKeyRead) -> String? {
    revokeFailed == key.uuid ? revokeFailure : nil
  }

  nonisolated static func nameProblem(_ name: String) -> String? {
    if name.isEmpty { return "Give the key a name." }
    if name.unicodeScalars.count > nameMaxLength { return "At most \(nameMaxLength) characters." }
    return nil
  }

  nonisolated public static let defaultScopes: Set<String> = ["dives:read"]

  // MARK: - What the block says

  public static let description =
    "Let a script or a tool of your own use your account through the API. A key's secret is"
    + " shown once, when you create it. Signing other devices out leaves keys working \u{2014}"
    + " each one is revoked here, on its own."
  public static let loadFailed = "Couldn't load your API keys."
  public static let createButton = "Create API key"
  public static let namePlaceholder = "laptop"
  public static let expired = "Expired"
  public static let permissionsTitle = "Key permissions"
  public static let permissionsLoadFailed = "Couldn't load supported permissions."
  public static let permissionsAbsent =
    "This API needs an update to support detailed permissions."
  public static let permissionsNote =
    "Create & edit allows changes to your content. Delete allows permanent removal. Species —"
    + " Create & edit also lets a tool propose photos, which the operator sees with your name, and"
    + " add species to the catalog every account shares."
  public static let noPermission = "Select at least one permission."
  public static let legacyAccess =
    "This key uses legacy access. Create a new key to choose individual permissions."
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
    case .scoped: "Custom permissions"
    }
  }

  nonisolated public static func label(_ lifetime: APIKeyLifetime) -> String {
    switch lifetime {
    case .oneHour: "1 hour"
    case .oneDay: "1 day"
    case .sevenDays: "7 days"
    case .thirtyDays: "30 days"
    case .ninetyDays: "90 days"
    case .oneYear: "1 year"
    case .never: "Never"
    }
  }

  /// `Created Oct 1, 2026 · Never used · Expires Oct 1, 2027`, by the day alone: the key's page.
  nonisolated public static func details(
    _ key: APIKeyRead, now: Date, in timeZone: TimeZone = .current
  ) -> String {
    "Created " + day(key.createdAt, now: now, in: timeZone) + " · "
      + usage(key, now: now, in: timeZone)
  }

  /// `Never used · Expires Oct 1, 2027`: the list's row, which leaves the day a key was made to
  /// its page.
  nonisolated public static func usage(
    _ key: APIKeyRead, now: Date, in timeZone: TimeZone = .current
  ) -> String {
    let used = key.lastUsedAt.map { "Last used " + day($0, now: now, in: timeZone) } ?? "Never used"
    let expires =
      key.expiresAt.map {
        (key.isExpired(at: now) ? "Expired " : "Expires ") + day($0, now: now, in: timeZone)
      } ?? "No expiry"
    return used + " · " + expires
  }

  nonisolated private static func day(
    _ timestamp: DiveTimestamp, now: Date, in timeZone: TimeZone
  ) -> String {
    DateText.inSentence(PasskeysModel.day(timestamp, timeZone, relativeTo: now))
  }
}

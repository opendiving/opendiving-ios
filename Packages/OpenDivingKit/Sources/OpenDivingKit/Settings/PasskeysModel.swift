import Foundation
import Observation

/// *Authentication*'s passkeys: each listed with whether it is synced and when it was added and
/// last used, renamed in its row and removed after a confirmation. The phone cannot create a
/// passkey, so there is no add, and with none on the account the block is left out. Direct
/// calls, online only.
@MainActor
@Observable
public final class PasskeysModel {
  /// The longest name the server stores.
  nonisolated public static let nameMaxLength = 50

  public let list: OptionalList<[PasskeyRead]>
  public let rename = InlineRename<UUID>(maxLength: PasskeysModel.nameMaxLength)
  /// The passkey waiting for the diver to confirm its removal.
  public var confirmingRemove: PasskeyRead?
  public private(set) var removing: UUID?
  /// Why the last removal failed.
  public private(set) var removeFailure: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    list = OptionalList(session: session) { try await $0.passkeys() }
  }

  /// False while the server has no passkeys, or the account has none.
  public var isShown: Bool {
    !list.isAbsent && list.value?.isEmpty != true
  }

  /// While a rename or a removal is on its way, neither starts.
  public var isBusy: Bool { rename.isSaving || removing != nil }

  public func saveRename() async {
    guard removing == nil, let uuid = rename.editing else { return }
    removeFailure = nil
    let name = rename.name
    let session = session
    let renamed = await rename.save { uuid, name in
      try await session.routedClient().renamePasskey(uuid, to: name)
    }
    // Patched in place: the name is all that changed.
    if renamed {
      list.update { $0.map { $0.uuid == uuid ? $0.renamed(name) : $0 } }
    }
  }

  /// Removes ``confirmingRemove``.
  public func confirmRemove() async {
    guard let passkey = confirmingRemove, !isBusy else { return }
    confirmingRemove = nil
    removeFailure = nil
    removing = passkey.uuid
    defer { removing = nil }
    do {
      try await session.routedClient().deletePasskey(passkey.uuid)
    } catch {
      removeFailure = APIError(error).message
      return
    }
    await list.load()
  }

  // MARK: - What the block says

  public static let description =
    "Sign in with your fingerprint, face or device PIN instead of waiting for an email. Your"
    + " email link keeps working either way."
  public static let addedOnTheWeb =
    "Passkeys are added on the web. The ones above still sign you in wherever they live."
  public static let synced = "Synced"
  public static let loadFailed = "Couldn't load your passkeys."
  public static let removeTitle = "Remove passkey"
  public static let removeButton = "Remove"

  public static func removeMessage(_ passkey: PasskeyRead) -> String {
    "\u{201C}\(passkey.name)\u{201D} will stop signing you in, and can't be brought back - a"
      + " replacement means going through the prompt again. Your device or password manager"
      + " keeps its own copy until you delete it there too."
  }

  /// `Added Oct 1, 2026 · Last used Nov 2, 2026`, by the day alone: the hour a passkey was
  /// added says nothing a diver deciding whether to remove it needs.
  nonisolated public static func details(_ passkey: PasskeyRead, in timeZone: TimeZone = .current)
    -> String
  {
    let used = passkey.lastUsedAt.map { "Last used " + day($0, timeZone) } ?? "Never used"
    return "Added " + day(passkey.createdAt, timeZone) + " · " + used
  }

  nonisolated static func day(_ timestamp: DiveTimestamp, _ timeZone: TimeZone) -> String {
    timestamp.instant.map { DateText.date($0, in: timeZone) } ?? DateText.diveDate(timestamp)
  }
}

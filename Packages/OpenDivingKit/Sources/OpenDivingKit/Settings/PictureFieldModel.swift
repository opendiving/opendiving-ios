import Foundation
import Observation

/// One of the account's two pictures: as a field of the form it is saved with, as the web's
/// `PictureField` has it, holding the edit the form will send after its fields; or, on *Account*,
/// sent as soon as it is chosen, by ``save(_:)``. Either way, what is stored, and the originals
/// fetched to adjust or copy a crop. Every call is direct and online only, through
/// ``Session/routedClient()``.
@MainActor
@Observable
public final class PictureFieldModel {
  public enum Opening: Hashable, Sendable {
    /// A new crop: over the pending edit's picture, or the original the server holds.
    case adjust
    /// The portrait from the profile picture's original.
    case copy
  }

  /// What a crop sheet opens on, once ``open(_:)`` has it.
  public enum Opened: Sendable {
    /// Bytes to measure, then crop as `purpose`.
    case bytes(Data, purpose: PictureCropping.Purpose, initial: PictureCrop?)
    /// The picture shown, which keeps no original: made ready as a pick is, and cropped as a
    /// replacement, which leaves it with an original like any other.
    case rendition(Data)
    /// A pending edit's own picture, which needs no fetch.
    case cropping(PictureCropping)
  }

  /// The control that takes a picture off the slot, or puts one back.
  public enum Bin: Hashable, Sendable {
    case keep, discard, remove

    public func label(_ kind: PictureKind) -> String {
      switch self {
      case .keep: "Keep your \(kind.label)"
      case .discard: "Discard the new \(kind.label)"
      case .remove: "Remove your \(kind.label)"
      }
    }
  }

  public let kind: PictureKind
  /// What the form will send after its fields; nil leaves the picture alone.
  public private(set) var edit: PictureEdit?
  /// Counts every change of ``edit``, for a view redrawing its preview to follow.
  public private(set) var revision = 0
  public private(set) var isSending = false
  /// Which original is being fetched, so its control can say so.
  public private(set) var opening: Opening?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private let avatar: AvatarModel?
  /// The last edit the server took, with the account it was sent over; ``sent`` says how long it
  /// is drawn.
  private var landed: (edit: PictureEdit, over: UserRead?)?
  private var portrait: (version: String, data: Data)?

  public init(kind: PictureKind, session: Session) {
    self.kind = kind
    self.session = session
    avatar = kind == .avatar ? AvatarModel(session: session) : nil
  }

  // MARK: - What the slot shows

  /// The stored rendition's digest; nil when there is none.
  public var storedSha: String? {
    kind == .avatar ? session.user?.avatarSha256 : session.user?.portraitSha256
  }

  private var storedOriginalSha: String? {
    kind == .avatar ? session.user?.avatarOriginalSha256 : session.user?.portraitOriginalSha256
  }

  private var storedCrop: PictureCrop? {
    kind == .avatar ? session.user?.avatarCrop : session.user?.portraitCrop
  }

  /// The stored rendition's bytes, once ``loadStored()`` has them for the version the account
  /// names: the previous version's are not them.
  public var storedData: Data? {
    guard let storedSha else { return nil }
    if let avatar { return avatar.version == storedSha ? avatar.data : nil }
    return portrait?.version == storedSha ? portrait?.data : nil
  }

  /// Whose initials an empty profile picture shows.
  public var initials: String? {
    session.user.flatMap { AvatarText.initials($0.name) }
  }

  /// An edit the server took, drawn until the stored picture shows what it made: while the
  /// account the session holds is the one it was sent over, the read after it having failed, and
  /// then until the bytes of the version the account names are to hand — so the previous
  /// picture never shows in between.
  public var sent: PictureEdit? {
    guard let landed else { return nil }
    return landed.over == session.user || storedData == nil ? landed.edit : nil
  }

  /// What the slot draws in place of the stored picture: the pending edit, or one that was
  /// ``sent``. A removal draws nothing.
  public var shown: PictureEdit? { edit ?? sent }

  /// Whether the stored picture is drawn.
  public var showsStored: Bool { shown == nil && storedSha != nil }

  private var isRemoved: Bool { edit == .remove }

  public var primaryLabel: String {
    shown?.source != nil || showsStored ? "Replace" : "Upload"
  }

  /// Whether *Adjust* has something to open: a pending picture, or a stored one.
  public var canAdjust: Bool {
    edit?.source != nil || (sent == nil && !isRemoved && storedSha != nil)
  }

  /// Whether the slot holds a picture to adjust or delete: the stored one, or one that landed
  /// and has not been read back.
  public var hasPicture: Bool { shown?.source != nil || showsStored }

  /// Whether *Use profile picture* has an original to copy.
  public var canCopy: Bool {
    kind == .portrait && sent == nil && session.user?.avatarOriginalSha256 != nil
  }

  public var bin: Bin? {
    if isRemoved { return .keep }
    if edit != nil { return .discard }
    return showsStored ? .remove : nil
  }

  /// What the slot will hold once the form is saved, in words: a preview alone cannot tell a new
  /// picture from the stored one.
  public var caption: String {
    let hasStored = storedSha != nil
    switch edit {
    case .replace:
      return hasStored ? "Replaces your \(kind.label) when you save." : "Added when you save."
    case .adjust:
      return "Re-cropped when you save."
    case .copy:
      return hasStored
        ? "Your profile picture replaces your portrait when you save."
        : "Your profile picture becomes your portrait when you save."
    case .remove:
      return "Removed when you save."
    case nil:
      return kind.help
    }
  }

  // MARK: - Editing

  public func set(_ edit: PictureEdit?) {
    self.edit = edit
    revision += 1
  }

  /// What the bin does: a pending picture is dropped, so the stored one comes back into view; a
  /// stored one is marked for removal; a removal is taken back.
  public func pressBin() {
    switch bin {
    case .keep, .discard: set(nil)
    case .remove: set(.remove)
    case nil: break
    }
  }

  /// The picture a crop is chosen on for `opening`, fetched where the phone does not hold it.
  public func open(_ opening: Opening) async -> Result<Opened, PictureRefusal> {
    if opening == .adjust, let edit, let source = edit.source {
      let purpose: PictureCropping.Purpose
      switch edit {
      case .replace(_, let filename, let type, _):
        purpose = .replace(filename: filename, type: type)
      case .copy: purpose = .copy
      case .adjust, .remove: purpose = .adjust
      }
      return .success(
        .cropping(PictureCropping(purpose: purpose, source: source, initial: edit.crop)))
    }
    self.opening = opening
    defer { self.opening = nil }
    let from: PictureKind = opening == .copy ? .avatar : kind
    do {
      let client = try session.routedClient()
      switch opening {
      case .copy:
        guard let version = session.user?.avatarOriginalSha256 else {
          return .failure(.couldNotLoad(.avatar, "It keeps no original."))
        }
        let original = try await client.pictureOriginal(.avatar, version: version)
        return .success(.bytes(original.data, purpose: .copy, initial: nil))
      case .adjust:
        if let version = storedOriginalSha {
          let original = try await client.pictureOriginal(kind, version: version)
          return .success(.bytes(original.data, purpose: .adjust, initial: storedCrop))
        }
        guard let version = storedSha else {
          return .failure(.couldNotLoad(kind, "There is none."))
        }
        if let storedData { return .success(.rendition(storedData)) }
        if kind == .avatar {
          return .success(.rendition(try await client.avatar(version: version).data))
        }
        let bytes = try Self.fetched(await client.portrait(version: version, etag: nil))
        return .success(.rendition(bytes.data))
      }
    } catch {
      return .failure(.couldNotLoad(from, APIError(error).message))
    }
  }

  // MARK: - Sending

  /// Sends `edit` at once, for a host with no form to wait for. Nil once the server took it;
  /// otherwise why not, with the edit dropped, so the slot shows what is stored again.
  public func save(_ edit: PictureEdit) async -> String? {
    guard !isSending else { return nil }
    set(edit)
    guard let refused = await send() else { return nil }
    set(nil)
    return edit == .remove
      ? "Your \(kind.label) was not deleted. \(refused)"
      : kind.notSaved(refused, afterFields: false)
  }

  /// Sends the edit, then reads the account, so every screen showing the picture shows the new
  /// one. Nil once the server took it; otherwise why not, with the edit kept for another try.
  public func send() async -> String? {
    guard let edit, !isSending else { return nil }
    isSending = true
    defer { isSending = false }
    do {
      let client = try session.routedClient()
      switch edit {
      case .replace(let source, let filename, let type, let crop):
        try await client.uploadPicture(
          kind, data: source.data, filename: filename, type: type, crop: crop)
      case .adjust(_, let crop):
        try await client.adjustPicture(kind, crop: crop)
      case .copy(_, let crop):
        try await client.copyAvatarToPortrait(crop: crop)
      case .remove:
        do {
          try await client.removePicture(kind)
        } catch APIError.http(let status, _) where status == 404 {
          // Removed already, elsewhere: what the diver asked for holds.
        }
      }
    } catch {
      return APIError(error).message
    }
    landed = (edit, session.user)
    set(nil)
    _ = try? await session.reloadAccount()
    return nil
  }

  // MARK: - The stored picture

  /// Shows what the account names: the phone's copy where it holds that version, else a fetched
  /// one. A fetch that fails leaves the slot as it was.
  public func loadStored() async {
    if let avatar {
      await avatar.load()
      return
    }
    guard let version = storedSha else {
      portrait = nil
      return
    }
    if portrait?.version == version { return }
    if let origin = session.state.origin {
      let sheets = CheckinSheetStore(store: session.store, origin: origin)
      if let file = sheets.load()?.portrait, file.version == version,
        let data = sheets.data(for: file)
      {
        portrait = (version, data)
        return
      }
    }
    guard
      let client = try? session.routedClient(),
      let bytes = try? Self.fetched(await client.portrait(version: version, etag: nil))
    else { return }
    portrait = (version, bytes.data)
  }

  private static func fetched(_ fetch: ConditionalFetch<FetchedBytes>) throws -> FetchedBytes {
    // Asked without an `ETag`, a 304 is not an answer.
    guard case .fetched(let bytes, _) = fetch else {
      throw APIError.unreadableResponse("304 for a picture asked for without an ETag")
    }
    return bytes
  }
}

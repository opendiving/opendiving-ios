import Foundation
import Observation

/// *Preferences*' tags: every one the diver has, with how many dives and sites carry each,
/// renamed in the row and deleted after a confirmation. Both are direct calls, online only;
/// after either every list and page over the account reads again, as after any direct write.
@MainActor
@Observable
public final class TagsModel: ReloadingListObserver {
  /// Nil until the first read lands.
  public private(set) var tags: [TagRead]?
  /// Why the last read failed, shown while there are no tags to show.
  public private(set) var loadFailure: String?
  public let rename = InlineRename<UUID>(maxLength: DiveFormBounds.tagMax)
  /// The tag waiting for the diver to confirm its delete.
  public var confirmingDelete: TagRead?
  public private(set) var deleting: UUID?
  /// Why the last delete failed.
  public private(set) var deleteFailure: String?

  @ObservationIgnored private let session: Session
  @ObservationIgnored var reloading: Task<Void, Never>?

  public init(session: Session) {
    self.session = session
  }

  /// While a rename or a delete is on its way, neither starts.
  public var isBusy: Bool { rename.isSaving || deleting != nil }

  /// "3 dives", or "3 dives, 1 site" where sites carry it.
  nonisolated public static func usage(_ tag: TagRead) -> String {
    let dives = count(tag.diveCount, "dive")
    return tag.siteCount > 0 ? dives + ", " + count(tag.siteCount, "site") : dives
  }

  nonisolated private static func count(_ n: Int, _ noun: String) -> String {
    "\(n) \(n == 1 ? noun : noun + "s")"
  }

  public static let confirmMessage =
    "Are you sure you want to delete this tag? The dives and sites carrying it keep everything"
    + " else, but will no longer be filed under it."

  /// Every page of `GET /tags`. With no route nothing is asked for: tags already read stay,
  /// and without any the screen says it needs a connection; ``followRoute()`` reads again.
  public func load() async {
    do {
      let client = try session.routedClient()
      tags = try await APIClient.allPages { page, perPage in
        try await client.tags(page: page, itemsPerPage: perPage)
      }
      loadFailure = nil
    } catch is CancellationError {
    } catch {
      loadFailure = APIError(error).message
    }
  }

  /// Reads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }

  public func saveRename() async {
    guard deleting == nil else { return }
    deleteFailure = nil
    let session = session
    let renamed = await rename.save { uuid, name in
      try await session.routedClient().renameTag(uuid, to: name)
    }
    if renamed { await reloadWithEveryList(on: session) }
  }

  /// Deletes ``confirmingDelete``.
  public func confirmDelete() async {
    guard let tag = confirmingDelete, !isBusy else { return }
    confirmingDelete = nil
    deleteFailure = nil
    deleting = tag.uuid
    defer { deleting = nil }
    do {
      try await session.routedClient().deleteTag(tag.uuid)
    } catch {
      deleteFailure = APIError(error).message
      return
    }
    await reloadWithEveryList(on: session)
  }

  func accountListsChanged() {
    reloading = Task { await load() }
  }
}

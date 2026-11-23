import Foundation
import Observation

/// *Added you*, over More's *People*: the divers who have the diver in their people and whom the
/// diver has not added, each read every page at once and kept, so the section shows offline from
/// the phone's copy. Hide and Disconnect are direct calls, online only, and the row leaves at once
/// when the server has answered.
@MainActor
@Observable
public final class AddedYouModel {
  public let rows: PagedList<AddedYouRow>
  /// The row waiting for the diver to confirm its disconnect.
  public var confirmingDisconnect: AddedYouRow?
  /// The row whose hide or disconnect is on its way.
  public private(set) var acting: UUID?
  /// Why the last hide or disconnect failed.
  public private(set) var failure: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    rows = PagedList(session: session, cache: .addedYou, routed: true, readsEveryPage: true) {
      client, page, itemsPerPage in
      try await client.addedYou(page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// What the section shows: nothing while it loads, nothing when it failed with nothing kept.
  public var shown: [AddedYouRow] { rows.phase == .loaded ? rows.items : [] }

  /// The list, or the list again on a return where it shows only the phone's copy, then read
  /// again as a route appears, until the calling task is cancelled.
  public func show() async {
    let seen = session.connectivity.routeAppearances
    await rows.rereadIfStale()
    if session.connectivity.routeAppearances != seen { await rows.rereadIfStale() }
    await session.connectivity.eachRouteAppearance { await rows.rereadIfStale() }
  }

  public func refresh() async {
    await rows.refresh()
  }

  /// *Hide*: the row goes and nothing else changes.
  public func hide(_ row: AddedYouRow) async {
    await act(on: row) { try await $0.hideAddedYou(row.uuid) }
  }

  /// Cuts `row`'s account's tie to the diver, the row the confirmation named. It is handed in
  /// rather than read from ``confirmingDisconnect``, which the dialog clears as it closes, before
  /// this runs.
  public func confirmDisconnect(_ row: AddedYouRow) async {
    confirmingDisconnect = nil
    await act(on: row) { try await $0.disconnectAddedYou(row.uuid) }
  }

  private func act(on row: AddedYouRow, _ call: (APIClient) async throws -> Void) async {
    guard acting == nil else { return }
    failure = nil
    acting = row.uuid
    defer { acting = nil }
    do {
      try await call(session.routedClient())
    } catch {
      failure = APIError(error).message
      return
    }
    Self.leave(row.uuid, session: session)
  }

  /// `account`'s row leaves every *Added you* on screen, until a page read since names it again.
  static func leave(_ account: UUID, session: Session) {
    guard let stores = AccountStores.current(session) else { return }
    let hub = OutboxHub.hub(for: stores.directory)
    hub.gone(account)
    hub.changed()
  }

  // MARK: - What the section says

  public static let title = "Added you"
  public static let explainer =
    "These divers have you in their people. They see your name, username and picture."
  public static let add = "Add"
  public static let hide = "Hide"
  public static let disconnect = "Disconnect"

  public static func disconnectTitle(_ row: AddedYouRow) -> String {
    "Disconnect \(row.name)"
  }

  public static func disconnectMessage(_ row: AddedYouRow) -> String {
    "\(row.name) keeps you in their people, as a name without your picture or username, and is"
      + " not told. They can connect again with your connect link until you reset it."
  }
}

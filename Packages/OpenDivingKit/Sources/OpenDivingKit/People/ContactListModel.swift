import Foundation
import Observation

/// More's *Contacts*: the diver's contacts in the API's order, every page of them over the
/// account's copy of the pages it has shown, since the page's letter index names every letter at
/// once. With no route nothing is asked for, and the list reads again once one appears.
@MainActor
@Observable
public final class ContactListModel {
  public let contacts: PagedList<ContactRead>

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    contacts = PagedList(session: session, cache: .contacts, routed: true, readsEveryPage: true) {
      client, page, itemsPerPage in
      try await client.contacts(page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// The list, or the list again on a return where it shows only the phone's copy, then read
  /// again as a route appears, until the calling task is cancelled.
  public func show() async {
    let seen = session.connectivity.routeAppearances
    await contacts.rereadIfStale()
    // A route that appeared while the read was skipped has no moment left to wait for.
    if session.connectivity.routeAppearances != seen { await contacts.rereadIfStale() }
    await session.connectivity.eachRouteAppearance { await contacts.rereadIfStale() }
  }

  /// Pull-to-refresh, from the first page through the last.
  public func refresh() async {
    await contacts.refresh()
  }
}

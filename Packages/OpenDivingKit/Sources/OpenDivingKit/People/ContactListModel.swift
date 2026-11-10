import Foundation
import Observation

/// More's *Contacts*: the diver's contacts in the API's order, a page at a time over the
/// account's copy of the pages it has shown. With no route nothing is asked for, and the list
/// reads again once one appears.
@MainActor
@Observable
public final class ContactListModel {
  public let contacts: PagedList<ContactRead>

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    contacts = PagedList(session: session, cache: .contacts, routed: true) {
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

  /// Pull-to-refresh, from the first page.
  public func refresh() async {
    await contacts.refresh()
  }

  /// Queues a contact's delete from its row; the reason it could not, where the outbox refused
  /// it.
  public static func delete(_ contact: UUID, in outbox: OutboxModel) -> String? {
    do {
      try outbox.queue(.deleteContact(.server(contact)))
      return nil
    } catch {
      return RecordSheetModel<ContactFormValues>.sentence(error)
    }
  }
}

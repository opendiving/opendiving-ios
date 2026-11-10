import Foundation
import Observation

/// More's *People*: the diver's people in the API's order, a page at a time over the account's
/// copy of the pages it has shown. With no route nothing is asked for, and the list reads again
/// once one appears.
@MainActor
@Observable
public final class PeopleListModel {
  public let people: PagedList<PersonRead>

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    people = PagedList(session: session, cache: .people, routed: true) {
      client, page, itemsPerPage in
      try await client.people(page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// The list, or the list again on a return where it shows only the phone's copy, then read
  /// again as a route appears, until the calling task is cancelled.
  public func show() async {
    let seen = session.connectivity.routeAppearances
    await people.rereadIfStale()
    // A route that appeared while the read was skipped has no moment left to wait for.
    if session.connectivity.routeAppearances != seen { await people.rereadIfStale() }
    await session.connectivity.eachRouteAppearance { await people.rereadIfStale() }
  }

  /// Pull-to-refresh, from the first page.
  public func refresh() async {
    await people.refresh()
  }

  /// Queues a person's delete, from their row or their page; the reason it could not, where the
  /// outbox refused it.
  public static func delete(_ person: UUID, in outbox: OutboxModel) -> String? {
    do {
      try outbox.queue(.deletePerson(.server(person)))
      return nil
    } catch {
      return RecordSheetModel<PersonFormValues>.sentence(error)
    }
  }
}

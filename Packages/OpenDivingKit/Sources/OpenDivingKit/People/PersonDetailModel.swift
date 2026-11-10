import Foundation
import Observation

/// A person's page: the person, and every dive that names them a page at a time. Each shows at
/// once from the account's copy where the phone has shown it, and with no route nothing is asked
/// for until one appears.
@MainActor
@Observable
public final class PersonDetailModel {
  public let page: RecordPage<PersonRead>
  public let dives: PagedList<DiveListItem>

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var appearancesAtLoad = 0

  public init(session: Session, personUUID: UUID) {
    self.session = session
    page = RecordPage(session: session, person: personUUID)
    dives = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize,
      cache: .personDives(personUUID), routed: true
    ) { client, page, itemsPerPage in
      try await client.dives(.person(personUUID), page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// The person, then their dives; on a return, whatever shows only the phone's copy, again.
  public func load() async {
    appearancesAtLoad = session.connectivity.routeAppearances
    await page.load()
    if page.phase.isLoaded { await dives.rereadIfStale() }
  }

  /// Pull-to-refresh. A person already on screen stays there when the refresh fails.
  public func refresh() async {
    await page.refresh()
    if page.phase.isLoaded { await dives.refresh() }
  }

  /// Reads again what a route can mend, each time one appears, until the calling task is
  /// cancelled.
  public func followRoute() async {
    if session.connectivity.routeAppearances != appearancesAtLoad { await reread() }
    await session.connectivity.eachRouteAppearance { await reread() }
  }

  private func reread() async {
    await page.reread()
    if page.phase.isLoaded { await dives.rereadIfStale() }
  }
}

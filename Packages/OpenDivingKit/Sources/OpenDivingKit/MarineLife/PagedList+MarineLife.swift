import Foundation

extension PagedList where Item == SpeciesLifeListEntry {
  /// More's *Marine Life*, most recently seen first, in pages of the web's grid's 24, over the
  /// account's copy of the pages it has shown.
  public static func lifeList(_ session: Session) -> PagedList<SpeciesLifeListEntry> {
    PagedList(session: session, itemsPerPage: 24, cache: .lifeList, routed: true) {
      client, page, itemsPerPage in
      try await client.speciesLifeList(page: page, itemsPerPage: itemsPerPage)
    }
  }
}

extension PagedList where Item == DiveSiteSearchRow {
  /// More's *Your dive sites*: the finder's search for the account's sites with no text and no
  /// view, which the server answers with every one of them, pinned or not, most recently dived
  /// first. It sends no camera, so its rows carry no distance.
  public static func yourDiveSites(_ session: Session) -> PagedList<DiveSiteSearchRow> {
    PagedList(
      session: session, itemsPerPage: APIClient.searchPageSize, cache: .yourDiveSites,
      routed: true
    ) { client, page, itemsPerPage in
      try await client.searchDiveSites(
        DiveSiteSearchQuery(yours: true), page: page, itemsPerPage: itemsPerPage
      ).listPage
    }
  }
}

extension PagedList {
  /// Shows the list, or shows it again on a return, then reads again each time a route
  /// appears, until the calling task is cancelled: how a `routed` list that skipped its read
  /// fills once the server can be reached. `session` is the one the list was made with.
  public func show(following session: Session) async {
    let seen = session.connectivity.routeAppearances
    await rereadIfStale()
    // A route that appeared while the read was skipped has no moment left to wait for.
    if session.connectivity.routeAppearances != seen { await rereadIfStale() }
    await session.connectivity.eachRouteAppearance { await rereadIfStale() }
  }
}

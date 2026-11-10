import Foundation

extension PagedList where Item == CertificationRead {
  /// More's *Certifications*, newest certified first, over the account's copy of the pages it has
  /// shown; with no route it asks for nothing.
  public static func certifications(_ session: Session) -> PagedList<CertificationRead> {
    PagedList(session: session, cache: .certifications, routed: true) {
      client, page, itemsPerPage in
      try await client.certifications(page: page, itemsPerPage: itemsPerPage)
    }
  }
}

extension PagedList where Item == CertificationRead {
  /// Shows the list, or shows it again on a return, then reads again each time a route appears,
  /// until the calling task is cancelled. `session` is the one the list was made with.
  public func showFollowingRoute(_ session: Session) async {
    let seen = session.connectivity.routeAppearances
    await rereadIfStale()
    // A route that appeared while the read was skipped has no moment left to wait for.
    if session.connectivity.routeAppearances != seen { await rereadIfStale() }
    await session.connectivity.eachRouteAppearance { await rereadIfStale() }
  }
}

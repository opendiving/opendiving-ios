import Foundation
import Observation

/// More's *Courses*: the diver's courses in the API's order, a page at a time over the
/// account's copy of the pages it has shown. With no route nothing is asked for, and the list
/// reads again once one appears.
@MainActor
@Observable
public final class CourseListModel {
  public let courses: PagedList<CourseRead>

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    courses = PagedList(session: session, cache: .courses, routed: true) {
      client, page, itemsPerPage in
      try await client.courses(page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// The list, or the list again on a return where it shows only the phone's copy, then read
  /// again as a route appears, until the calling task is cancelled.
  public func show() async {
    let seen = session.connectivity.routeAppearances
    await courses.rereadIfStale()
    // A route that appeared while the read was skipped has no moment left to wait for.
    if session.connectivity.routeAppearances != seen { await courses.rereadIfStale() }
    await session.connectivity.eachRouteAppearance { await courses.rereadIfStale() }
  }

  /// Pull-to-refresh, from the first page.
  public func refresh() async {
    await courses.refresh()
  }
}

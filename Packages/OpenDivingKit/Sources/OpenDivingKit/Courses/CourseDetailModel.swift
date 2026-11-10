import Foundation
import Observation

/// A course's page: the course, the certifications it issued, and the dives logged on it a page
/// at a time. Each shows at once from the account's copy where the phone has shown it, and with
/// no route nothing is asked for until one appears.
@MainActor
@Observable
public final class CourseDetailModel {
  public let page: RecordPage<CourseRead>
  /// One page, never more: a course issues one or two cards, and the web lists at most this many.
  public let certifications: PagedList<CertificationRead>
  public let dives: PagedList<DiveListItem>

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var appearancesAtLoad = 0

  /// The most certifications the page lists, the web's ceiling.
  public static let certificationsLimit = 50

  public init(session: Session, courseUUID: UUID) {
    self.session = session
    page = RecordPage(session: session, course: courseUUID)
    certifications = PagedList(
      session: session, itemsPerPage: Self.certificationsLimit,
      cache: .courseCertifications(courseUUID), routed: true
    ) { client, page, itemsPerPage in
      try await client.certifications(
        courseUUID: courseUUID, page: page, itemsPerPage: itemsPerPage)
    }
    dives = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize,
      cache: .courseDives(courseUUID), routed: true
    ) { client, page, itemsPerPage in
      try await client.dives(.course(courseUUID), page: page, itemsPerPage: itemsPerPage)
    }
  }

  /// The course, then its certifications and dives; on a return, whatever shows only the
  /// phone's copy, again.
  public func load() async {
    appearancesAtLoad = session.connectivity.routeAppearances
    await page.load()
    if page.phase.isLoaded { await rereadLists() }
  }

  /// Pull-to-refresh. A course already on screen stays there when the refresh fails.
  public func refresh() async {
    await page.refresh()
    guard page.phase.isLoaded else { return }
    async let certifications: Void = self.certifications.refresh()
    async let dives: Void = self.dives.refresh()
    _ = await (certifications, dives)
  }

  /// Reads again what a route can mend, each time one appears, until the calling task is
  /// cancelled.
  public func followRoute() async {
    if session.connectivity.routeAppearances != appearancesAtLoad { await reread() }
    await session.connectivity.eachRouteAppearance { await reread() }
  }

  private func reread() async {
    await page.reread()
    if page.phase.isLoaded { await rereadLists() }
  }

  private func rereadLists() async {
    async let certifications: Void = self.certifications.rereadIfStale()
    async let dives: Void = self.dives.rereadIfStale()
    _ = await (certifications, dives)
  }

  /// Queues the course's delete from its page; the reason it could not, where the outbox
  /// refused it.
  public static func delete(_ course: UUID, in outbox: OutboxModel) -> String? {
    do {
      try outbox.queue(.deleteCourse(.server(course)))
      return nil
    } catch {
      return RecordSheetModel<CourseFormValues>.sentence(error)
    }
  }
}

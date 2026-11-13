import Foundation
import Synchronization
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// More's *Courses* and a course's page as the phone reads them: the kept pages shown offline
/// and read again once a route appears, a course's certifications and dives asked for by the
/// course, a queued delete showing at once, and *Log a dive* opening with the course chosen.
@MainActor
struct CourseReadsTests {
  /// `course.json`'s uuid, the first row of `courses-page`.
  private static let first = UUID(uuidString: "01a0a5da-6c85-770b-a009-8c7b4044c060")!

  /// A phone whose server answers the course list, the first course's page, its certifications
  /// and its dives, and holds every write as if there were no route.
  private func world(asked: Asked? = nil) throws -> OutboxWorld {
    let world = try OutboxWorld()
    let courses = try KitFixture.text("courses-page")
    let course = try KitFixture.text("course")
    let certifications =
      #"{"data":["# + (try KitFixture.text("certification-front-only"))
      + #"],"total_count":1,"has_more":false,"page":1,"items_per_page":50}"#
    let dives = try KitFixture.text("dives-page")
    let courseRoute = "GET course/" + APIClient.wire(Self.first)
    world.server.override { request, _ in
      guard request.route.hasPrefix("GET ") else { throw URLError(.notConnectedToInternet) }
      asked?.queries.withLock { $0.append(request.route + "?" + (request.url?.query ?? "")) }
      return switch request.route {
      case "GET courses": .json(courses)
      case courseRoute: .json(course)
      case "GET certifications": .json(certifications)
      case "GET dives": .json(dives)
      default: nil
      }
    }
    return world
  }

  /// Every read the server was sent, with its query.
  final class Asked: Sendable {
    let queries = Mutex<[String]>([])
  }

  @Test func theListShowsOfflineAndReadsOnceARouteAppears() async throws {
    let first = try world()
    try await first.load()
    let online = CourseListModel(session: first.session)
    await online.courses.load()
    #expect(online.courses.items.map(\.uuid).first == Self.first)

    let route = RouteSwitch()
    let world = try first.relaunched(connectivity: route)
    try await world.session.loadAccount()
    let mark = world.server.mark
    let offline = CourseListModel(session: world.session)
    let showing = Task { await offline.show() }
    while !route.isFollowed { await Task.yield() }
    #expect(offline.courses.items.map(\.uuid) == online.courses.items.map(\.uuid))
    #expect(offline.courses.lastUpdated != nil)
    #expect(world.server.count("GET courses", since: mark) == 0)

    route.appear()
    while offline.courses.fetchedAt != nil { await Task.yield() }
    showing.cancel()
    #expect(world.server.count("GET courses", since: mark) == 1)
  }

  @Test func thePageAsksForTheCoursesCertificationsAndDives() async throws {
    let asked = Asked()
    let world = try world(asked: asked)
    try await world.load()
    let page = CourseDetailModel(session: world.session, courseUUID: Self.first)
    await page.load()
    guard case .loaded(let course) = page.page.phase else {
      Issue.record("The course was not read")
      return
    }
    #expect(course.name == "Solo Diver")
    #expect(page.certifications.items.map(\.name) == ["Solo Diver"])
    #expect(!page.dives.items.isEmpty)
    let wire = APIClient.wire(Self.first)
    let queries = asked.queries.withLock { $0 }
    #expect(
      queries.contains(
        "GET certifications?page=1&items_per_page=\(CourseDetailModel.certificationsLimit)"
          + "&course_uuid=\(wire)"))
    #expect(queries.contains { $0.hasPrefix("GET dives?") && $0.contains("course_uuid=\(wire)") })
  }

  @Test func aQueuedDeleteTakesTheRowAtOnce() async throws {
    let world = try world()
    try await world.load()
    let model = CourseListModel(session: world.session)
    await model.courses.load()
    #expect(model.courses.items.contains { $0.uuid == Self.first })
    #expect(CourseDetailModel.delete(Self.first, in: world.outbox()) == nil)
    #expect(!model.courses.items.contains { $0.uuid == Self.first })
  }

  @Test func aQueuedEditShowsAsThePendingLine() async throws {
    let world = try world()
    try await world.load()
    let page = CourseDetailModel(session: world.session, courseUUID: Self.first)
    await page.load()
    #expect(!page.page.hasPendingEdit)
    var update = CourseUpdate()
    update.notes = "Line drills."
    try world.outbox().queue(.updateCourse(.server(Self.first), update))
    #expect(page.page.hasPendingEdit)
  }

  @Test func aDiveLoggedForACourseOpensWithTheCourseChosen() async throws {
    let world = try FormWorld()
    try await world.loaded()
    world.offline()
    let model = await world.form(.course(Self.first))
    #expect(model.values.course == .server(Self.first))
    #expect(model.shows(.course))
    #expect(model.title == "Log New Dive")
    #expect(!model.isTouched)
  }
}

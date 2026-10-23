import Foundation
import OpenDivingKit
import Synchronization

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A server holding one account's whole check-in sheet: two cards, the first with a front, a
/// course, a dive centre and an instructor, the second with a back alone. Pictures carry an
/// `ETag` and answer 304 to it; `failing` names a route that stops answering.
final class CheckinSheetServer: Sendable {
  static let frontUUID = "01a0b07a-2e5b-792f-b35b-98009ab92952"
  static let backUUID = "01a0b07b-0000-7000-8000-000000000002"
  static let firstCard = "01a0b07a-206e-76bd-bc56-e9646791ba20"
  static let secondCard = "01a0b07b-0000-7000-8000-000000000001"
  static let frontRoute = "GET certification/\(firstCard)/file/front"
  static let backRoute = "GET certification/\(secondCard)/file/back"

  let failing = Mutex<Set<String>>([])
  let pictures = Mutex<[String: (bytes: Data, etag: String)]>([
    "GET user/portrait": (Data("portrait-1".utf8), "\"p1\""),
    frontRoute: (Data("front-1".utf8), "\"f1\""),
    backRoute: (Data("back-1".utf8), "\"b1\""),
  ])

  private let json: [String: StubTransport.Response]

  init() throws {
    json = try Self.routes()
  }

  func transport() -> StubTransport {
    StubTransport { [self] request in try answer(request) }
  }

  func answer(_ request: URLRequest) throws -> StubTransport.Response {
    let route = request.route
    if failing.withLock({ $0.contains(route) }) { throw URLError(.notConnectedToInternet) }
    if let picture = pictures.withLock({ $0[route] }) {
      if request.value(forHTTPHeaderField: "If-None-Match") == picture.etag {
        return StubTransport.Response(status: 304)
      }
      return StubTransport.Response(
        headers: ["ETag": picture.etag, "Content-Type": "image/webp"], body: picture.bytes)
    }
    return json[route] ?? .json(#"{"detail":"Not Found"}"#, status: 404)
  }

  private static func routes() throws -> [String: StubTransport.Response] {
    let first = try KitFixture.text("certification-front-only")
    let second = """
      {"uuid":"\(secondCard)","agency":"other","agency_other":"Reef Club","name":"Reef Diver",
       "certification_number":null,"certified_on":null,"expires_on":"2026-11-01",
       "instructor_number":null,"notes":"Laminated","user_uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923",
       "course_uuid":null,"contact_uuid":null,"instructor_uuid":null,
       "files":[{"uuid":"\(backUUID)","side":"back","content_type":"image/webp","byte_size":6,
       "original_filename":"back.webp","updated_at":null}],
       "created_at":"2026-09-17T17:46:28Z"}
      """
    let people = """
      {"data":[{"uuid":"01a0e2ed-1be6-72f8-8057-0b0caa945758","name":"Ivy Instructor",
       "email":null,"phone":null,"notes":"","username":null,"dive_count":0,
       "created_at":"2026-09-27T12:53:05Z","updated_at":null}],
       "total_count":1,"has_more":false,"page":1,"items_per_page":50}
      """
    return [
      "GET user": .json(try KitFixture.text("user")),
      "GET people": .json(people),
      "GET user/checkin-details": .json(try KitFixture.text("checkin-details")),
      "GET user/dive-stats": .json(try KitFixture.text("dive-stats")),
      "GET dives": .json(try KitFixture.text("dives-page")),
      "GET certifications": .json(
        #"{"data":[\#(first),\#(second)],"total_count":2,"has_more":false,"page":1,"items_per_page":50}"#
      ),
      "GET course/01a0a5da-6c85-770b-a009-8c7b4044c060": .json(try KitFixture.text("course")),
      "GET contact/01a0d9e9-bdd0-793a-829f-5dc90613f84f": .json(try KitFixture.text("contact")),
      "POST auth/logout": .json(#"{"message":"Logged out successfully"}"#),
    ]
  }
}
